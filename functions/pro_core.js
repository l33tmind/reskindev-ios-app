/** Shared Reskindev Pro helpers (not Cloud Functions): plans and writing users/{uid}.pro */
const admin = require("firebase-admin");

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


module.exports = { PLANS, planForProduct, grantPro, endPro };
