/**
 * Reskindev Pro: one subscription for the website, iOS, Android and Vision Pro.
 *
 * The single source of truth is users/{uid}.pro, written ONLY here (Firestore rules block clients):
 *   pro: {
 *     active: true | false,
 *     plan: "monthly" | "yearly",
 *     source: "apple" | "google" | "wallet" | "admin",
 *     productId: "reskindev.pro.monthly" | "reskindev.pro.yearly" | null,
 *     startedAt, expiresAt, updatedAt: Timestamp,
 *     autoRenew: bool,
 *     appleOriginalTransactionId?, googlePurchaseToken?
 *   }
 * Every app treats someone as Pro when pro.active && pro.expiresAt > now.
 *
 * Ways in:
 *  - verifyAppleSubscription: StoreKit 2 signed transaction (iPhone, Vision Pro) → verified with Apple's certificates
 *  - verifyGoogleSubscription: Play Billing purchase token (Android) → checked with the Play Developer API
 *  - buyProWithWallet: website (and any platform where it's allowed) pays from the Reskindev wallet
 *  - adminSetPro: admin gives or removes Pro
 *  - appleSubscriptionWebhook: App Store Server Notifications V2 (renewals, refunds, cancellations)
 *  - expireProSubscriptions: daily clean-up of lapsed subscriptions
 */
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineString } = require("firebase-functions/params");
const admin = require("firebase-admin");

const REGION = "asia-south1";
const BUNDLE_ID = "com.reskindevdotcom.reskindev";
const ANDROID_PACKAGE = "com.reskindevdotcom.reskindev";
// App Store Connect → App Information → Apple ID (numbers). Needed to verify production transactions.
const APPLE_APP_ID = defineString("APPLE_APP_ID", { default: "" });

const PLANS = {
    monthly: { productId: "reskindev.pro.monthly", price: 9.99, days: 30 },
    yearly: { productId: "reskindev.pro.yearly", price: 99.99, days: 365 },
};
const planForProduct = (productId) =>
    Object.keys(PLANS).find((k) => PLANS[k].productId === productId) || null;

const db = () => admin.firestore();
const ts = (ms) => admin.firestore.Timestamp.fromMillis(ms);

/** Writes users/{uid}.pro and tells the person when Pro starts */
async function grantPro(uid, data) {
    const ref = db().collection("users").doc(uid);
    const before = (await ref.get()).data() || {};
    const wasActive = before.pro && before.pro.active && before.pro.expiresAt && before.pro.expiresAt.toMillis() > Date.now();
    const pro = {
        active: data.expiresAtMs > Date.now(),
        plan: data.plan,
        source: data.source,
        productId: data.productId || null,
        startedAt: (before.pro && before.pro.startedAt && wasActive) ? before.pro.startedAt : admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: ts(data.expiresAtMs),
        autoRenew: !!data.autoRenew,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(data.appleOriginalTransactionId ? { appleOriginalTransactionId: data.appleOriginalTransactionId } : {}),
        ...(data.googlePurchaseToken ? { googlePurchaseToken: data.googlePurchaseToken } : {}),
    };
    await ref.set({ pro }, { merge: true });
    await db().collection("pro_events").add({
        uid, ...pro, startedAt: null, updatedAt: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (pro.active && !wasActive) {
        await db().collection("notifications").add({
            userId: uid,
            title: "Welcome to Reskindev Pro ⚡",
            message: "Your Pro badge is on. You can now message sellers and send photos and videos before ordering.",
            type: "pro",
            link: "/settings/pro",
            route: "/pro",
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    return { active: pro.active, plan: pro.plan, source: pro.source, expiresAt: data.expiresAtMs };
}

async function endPro(uid, reason) {
    await db().collection("users").doc(uid).set({
        pro: { active: false, autoRenew: false, endedReason: reason, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    }, { merge: true });
}

// ---------------- Apple (StoreKit 2) ----------------

let appleRootCerts = null;
async function appleRoots() {
    if (appleRootCerts) return appleRootCerts;
    const urls = [
        "https://www.apple.com/certificateauthority/AppleRootCA-G3.cer",
        "https://www.apple.com/certificateauthority/AppleRootCA-G2.cer",
        "https://www.apple.com/certificateauthority/AppleComputerRootCertificate.cer",
    ];
    appleRootCerts = await Promise.all(urls.map(async (u) => Buffer.from(await (await fetch(u)).arrayBuffer())));
    return appleRootCerts;
}

/** Verifies a signed transaction (JWS) in production, then sandbox (TestFlight / Xcode builds) */
async function verifyAppleTransaction(jws) {
    const { SignedDataVerifier, Environment } = require("@apple/app-store-server-library");
    const roots = await appleRoots();
    const appId = APPLE_APP_ID.value() ? Number(APPLE_APP_ID.value()) : undefined;
    const tries = [
        ...(appId ? [new SignedDataVerifier(roots, true, Environment.PRODUCTION, BUNDLE_ID, appId)] : []),
        new SignedDataVerifier(roots, true, Environment.SANDBOX, BUNDLE_ID),
        new SignedDataVerifier(roots, true, Environment.XCODE, BUNDLE_ID),
    ];
    let lastError;
    for (const v of tries) {
        try {
            return await v.verifyAndDecodeTransaction(jws);
        } catch (e) {
            lastError = e;
        }
    }
    throw lastError || new Error("Could not verify the App Store transaction.");
}

async function applyAppleTransaction(uid, tx) {
    const plan = planForProduct(tx.productId);
    if (!plan) throw new HttpsError("invalid-argument", "Unknown product.");
    if (tx.revocationDate) {
        await endPro(uid, "refunded");
        return { active: false };
    }
    // One Apple subscription belongs to one Reskindev account
    const other = await db().collection("users").where("pro.appleOriginalTransactionId", "==", String(tx.originalTransactionId)).limit(1).get();
    if (!other.empty && other.docs[0].id !== uid) {
        throw new HttpsError("already-exists", "This App Store subscription is already linked to another Reskindev account.");
    }
    return grantPro(uid, {
        plan, source: "apple", productId: tx.productId,
        expiresAtMs: Number(tx.expiresDate) || 0,
        autoRenew: true,
        appleOriginalTransactionId: String(tx.originalTransactionId),
    });
}

exports.verifyAppleSubscription = onCall({ region: REGION }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in first.");
    const jws = request.data && request.data.signedTransaction;
    if (!jws || typeof jws !== "string") throw new HttpsError("invalid-argument", "Missing transaction.");
    let tx;
    try {
        tx = await verifyAppleTransaction(jws);
    } catch (e) {
        console.error("Apple verify failed", e);
        throw new HttpsError("permission-denied", "The App Store purchase could not be verified.");
    }
    if (tx.bundleId !== BUNDLE_ID) throw new HttpsError("permission-denied", "Wrong app.");
    return applyAppleTransaction(request.auth.uid, tx);
});

/** App Store Server Notifications V2. Set this function's URL in App Store Connect → App Information. */
exports.appleSubscriptionWebhook = onRequest({ region: REGION }, async (req, res) => {
    try {
        const { SignedDataVerifier, Environment } = require("@apple/app-store-server-library");
        const roots = await appleRoots();
        const appId = APPLE_APP_ID.value() ? Number(APPLE_APP_ID.value()) : undefined;
        const verifiers = [
            ...(appId ? [new SignedDataVerifier(roots, true, Environment.PRODUCTION, BUNDLE_ID, appId)] : []),
            new SignedDataVerifier(roots, true, Environment.SANDBOX, BUNDLE_ID),
        ];
        let note, verifier;
        for (const v of verifiers) {
            try { note = await v.verifyAndDecodeNotification(req.body.signedPayload); verifier = v; break; } catch (_) { /* next */ }
        }
        if (!note) { res.status(400).send("bad payload"); return; }
        const tx = note.data && note.data.signedTransactionInfo
            ? await verifier.verifyAndDecodeTransaction(note.data.signedTransactionInfo) : null;
        if (tx) {
            const owner = await db().collection("users").where("pro.appleOriginalTransactionId", "==", String(tx.originalTransactionId)).limit(1).get();
            if (!owner.empty) {
                const uid = owner.docs[0].id;
                if (["EXPIRED", "REFUND", "REVOKE"].includes(note.notificationType)) await endPro(uid, note.notificationType.toLowerCase());
                else await applyAppleTransaction(uid, tx);
            }
        }
        res.status(200).send("ok");
    } catch (e) {
        console.error("Apple webhook error", e);
        res.status(500).send("error");
    }
});

// ---------------- Google Play ----------------

exports.verifyGoogleSubscription = onCall({ region: REGION }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in first.");
    const { purchaseToken, productId } = request.data || {};
    const plan = planForProduct(productId);
    if (!purchaseToken || !plan) throw new HttpsError("invalid-argument", "Missing purchase.");

    // The Firebase service account must be invited in Play Console → Users and permissions (view financial data)
    const { GoogleAuth } = require("google-auth-library");
    const client = await new GoogleAuth({ scopes: ["https://www.googleapis.com/auth/androidpublisher"] }).getClient();
    const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${ANDROID_PACKAGE}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
    let sub;
    try {
        sub = (await client.request({ url })).data;
    } catch (e) {
        console.error("Play verify failed", e.response ? e.response.data : e);
        throw new HttpsError("permission-denied", "The Google Play purchase could not be verified.");
    }
    const okStates = ["SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"];
    if (!okStates.includes(sub.subscriptionState)) {
        throw new HttpsError("failed-precondition", "This subscription is not active.");
    }
    const line = (sub.lineItems || []).find((l) => l.productId === productId) || (sub.lineItems || [])[0];
    const expiresAtMs = line && line.expiryTime ? Date.parse(line.expiryTime) : Date.now() + PLANS[plan].days * 86400000;

    const other = await db().collection("users").where("pro.googlePurchaseToken", "==", purchaseToken).limit(1).get();
    if (!other.empty && other.docs[0].id !== request.auth.uid) {
        throw new HttpsError("already-exists", "This Google Play subscription is already linked to another Reskindev account.");
    }
    // Play cancels unacknowledged purchases after 3 days
    if (sub.acknowledgementState !== "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED") {
        try {
            await client.request({
                url: `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${ANDROID_PACKAGE}/purchases/subscriptions/${productId}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`,
                method: "POST",
                data: {},
            });
        } catch (e) {
            console.error("Play acknowledge failed", e.response ? e.response.data : e);
        }
    }
    return grantPro(request.auth.uid, {
        plan, source: "google", productId,
        expiresAtMs,
        autoRenew: !!(line && line.autoRenewingPlan && line.autoRenewingPlan.autoRenewEnabled),
        googlePurchaseToken: purchaseToken,
    });
});

// ---------------- Wallet (website) ----------------

exports.buyProWithWallet = onCall({ region: REGION }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in first.");
    const planKey = request.data && request.data.plan;
    const plan = PLANS[planKey];
    if (!plan) throw new HttpsError("invalid-argument", "Choose monthly or yearly.");
    const uid = request.auth.uid;
    const ref = db().collection("users").doc(uid);

    let expiresAtMs = 0;
    await db().runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const u = snap.data() || {};
        const wallet = Number(u.walletBalance || 0);
        if (wallet + 1e-9 < plan.price) {
            throw new HttpsError("failed-precondition", `Your wallet has $${wallet.toFixed(2)}. Pro ${planKey} costs $${plan.price}.`);
        }
        // Buying again extends from the current end date, so no paid day is lost
        const current = u.pro && u.pro.expiresAt ? u.pro.expiresAt.toMillis() : 0;
        expiresAtMs = Math.max(Date.now(), current) + plan.days * 86400000;
        tx.update(ref, { walletBalance: admin.firestore.FieldValue.increment(-plan.price) });
        tx.set(db().collection("pro_payments").doc(), {
            uid, plan: planKey, amount: plan.price, source: "wallet",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    });
    return grantPro(uid, { plan: planKey, source: "wallet", productId: plan.productId, expiresAtMs, autoRenew: false });
});

// ---------------- Admin ----------------

exports.adminSetPro = onCall({ region: REGION }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in first.");
    const me = await db().collection("users").doc(request.auth.uid).get();
    if (!me.exists || me.data().role !== "admin") throw new HttpsError("permission-denied", "Admins only.");
    const { uid, days, revoke } = request.data || {};
    if (!uid) throw new HttpsError("invalid-argument", "Missing user.");
    if (revoke) {
        await endPro(uid, "admin");
        return { active: false };
    }
    const d = Math.max(1, Math.min(3650, Number(days) || 30));
    const target = (await db().collection("users").doc(uid).get()).data() || {};
    const current = target.pro && target.pro.expiresAt ? target.pro.expiresAt.toMillis() : 0;
    return grantPro(uid, {
        plan: d >= 365 ? "yearly" : "monthly", source: "admin", productId: null,
        expiresAtMs: Math.max(Date.now(), current) + d * 86400000,
        autoRenew: false,
    });
});

// ---------------- Housekeeping ----------------

/** Once a day: Pro that ran out (store renewals arrive by webhook or when the app restores purchases) */
exports.expireProSubscriptions = onSchedule({ schedule: "every 24 hours", region: REGION }, async () => {
    // A day of grace for store renewals that are still on their way
    const cutoff = ts(Date.now() - 86400000);
    const snap = await db().collection("users").where("pro.active", "==", true).where("pro.expiresAt", "<", cutoff).get();
    for (const doc of snap.docs) await endPro(doc.id, "expired");
});
