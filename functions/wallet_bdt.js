/**
 * Taka (BDT) wallet for people in Bangladesh: deposit taka to the admin's bank / mobile banking,
 * the admin confirms it, then the person converts taka to the site's dollars (3% fee by default)
 * and spends those dollars from the normal wallet (users.walletBalance).
 *
 * Firestore (all money fields are written ONLY here; rules block clients):
 *   users/{uid}.walletBdt                 taka balance (number, 2 decimals)
 *   users/{uid}.walletBalance             dollar balance (existing)
 *   settings/bdtWallet                    { bdtPerUsd, rateMode: "live"|"manual" (live = refreshBdtRate every 6 h), convertFeePercent, minDepositBdt, maxDepositBdt, enabled,
 *                                           methods: [{ id, type: "bank"|"bkash"|"nagad"|"rocket", title,
 *                                                       accountName, accountNumber, bankName?, branch?, routing?, note? }] }
 *                                         (admins edit it from the admin panel; anyone signed in can read)
 *   bdt_deposits/{id}                     { uid, name, email, amountBdt, methodId, methodTitle, senderAccount,
 *                                           transactionId, receiptPath?, status: "pending"|"approved"|"rejected",
 *                                           createdAt, reviewedAt?, reviewedBy?, rejectReason?, creditedBdt? }
 *   wallet_transactions/{id}              every balance change: { uid, type: "bdt_deposit"|"bdt_to_usd"|"bdt_adjust",
 *                                           amountBdt, amountUsd, feeBdt, rate, refId, createdAt }
 * Receipts: Storage deposits/{uid}/... (owner + admins only).
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

const REGION = "asia-south1";
const db = () => admin.firestore();
const now = () => admin.firestore.FieldValue.serverTimestamp();
const round2 = (n) => Math.round((Number(n) || 0) * 100) / 100;

const DEFAULTS = { bdtPerUsd: 122, rateMode: "live", convertFeePercent: 3, minDepositBdt: 100, maxDepositBdt: 500000, enabled: true, methods: [] };

/** Market USD→BDT from open.er-api.com (free, daily). Ignores anything outside a sane band. */
async function fetchLiveRate() {
    const res = await fetch("https://open.er-api.com/v6/latest/USD");
    const data = await res.json();
    const rate = Number(data && data.rates && data.rates.BDT);
    if (!(rate > 80 && rate < 200)) throw new Error(`Odd BDT rate: ${rate}`);
    return Math.round(rate * 100) / 100;
}

async function refreshLiveRate() {
    const ref = db().collection("settings").doc("bdtWallet");
    const cur = (await ref.get()).data() || {};
    if ((cur.rateMode || DEFAULTS.rateMode) !== "live") return null;
    const rate = await fetchLiveRate();
    await ref.set({ bdtPerUsd: rate, liveRate: rate, rateUpdatedAt: now(), rateSource: "open.er-api.com" }, { merge: true });
    return rate;
}

/** Every 6 hours: keep the live rate fresh (the last good rate stays if the source is down) */
exports.refreshBdtRate = onSchedule({ schedule: "every 6 hours", region: REGION }, async () => {
    try { await refreshLiveRate(); } catch (e) { console.error("BDT rate refresh failed", e); }
});

async function settings() {
    const snap = await db().collection("settings").doc("bdtWallet").get();
    return { ...DEFAULTS, ...(snap.exists ? snap.data() : {}) };
}

/** Bangladesh is chosen in the profile (countryCode "BD", or the older free-text country field) */
function isBangladesh(u) {
    const code = String((u && u.countryCode) || "").toUpperCase();
    const name = String((u && u.country) || "").trim().toLowerCase();
    return code === "BD" || name === "bangladesh" || name === "বাংলাদেশ";
}

async function requireAdmin(request) {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in first.");
    const me = await db().collection("users").doc(request.auth.uid).get();
    if (!me.exists || me.data().role !== "admin") throw new HttpsError("permission-denied", "Admins only.");
    return { uid: request.auth.uid, name: me.data().displayName || me.data().name || "Admin" };
}

async function notify(uid, title, message, type) {
    await db().collection("notifications").add({
        userId: uid, title, message, type, link: "/profile/wallet", route: "/wallet", read: false, createdAt: now(),
    });
}

/** Person: "I sent X taka, here is the transaction ID" */
exports.requestBdtDeposit = onCall({ region: REGION }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in first.");
    const uid = request.auth.uid;
    const user = (await db().collection("users").doc(uid).get()).data() || {};
    if (!isBangladesh(user)) throw new HttpsError("failed-precondition", "Taka deposits are for accounts in Bangladesh. Choose Bangladesh in your settings.");
    const s = await settings();
    if (!s.enabled) throw new HttpsError("unavailable", "Taka deposits are paused right now. Please try later.");

    const d = request.data || {};
    const amountBdt = round2(d.amountBdt);
    const method = (s.methods || []).find((m) => m.id === d.methodId);
    const transactionId = String(d.transactionId || "").trim().slice(0, 80);
    const senderAccount = String(d.senderAccount || "").trim().slice(0, 80);
    const receiptPath = String(d.receiptPath || "").trim().slice(0, 300);

    if (!method) throw new HttpsError("invalid-argument", "Choose where you sent the money.");
    if (!(amountBdt >= s.minDepositBdt)) throw new HttpsError("invalid-argument", `The minimum deposit is ৳${s.minDepositBdt}.`);
    if (amountBdt > s.maxDepositBdt) throw new HttpsError("invalid-argument", `The maximum deposit is ৳${s.maxDepositBdt}.`);
    if (transactionId.length < 4) throw new HttpsError("invalid-argument", "Enter the transaction ID / reference from your bank or app.");
    if (!senderAccount) throw new HttpsError("invalid-argument", "Enter the account or number you sent the money from.");
    if (receiptPath && !receiptPath.startsWith(`deposits/${uid}/`)) throw new HttpsError("invalid-argument", "Invalid receipt.");

    // The same transaction ID can only be claimed once
    const dup = await db().collection("bdt_deposits").where("transactionId", "==", transactionId).limit(1).get();
    if (!dup.empty) throw new HttpsError("already-exists", "This transaction ID was already submitted.");
    const open = await db().collection("bdt_deposits").where("uid", "==", uid).where("status", "==", "pending").get();
    if (open.size >= 5) throw new HttpsError("resource-exhausted", "You have 5 deposits waiting. Please wait for them to be checked.");

    const ref = await db().collection("bdt_deposits").add({
        uid, name: user.displayName || user.name || "", email: user.email || "",
        amountBdt, methodId: method.id, methodTitle: method.title || method.type, methodType: method.type,
        senderAccount, transactionId, receiptPath: receiptPath || null,
        status: "pending", createdAt: now(),
    });

    const admins = await db().collection("users").where("role", "==", "admin").get();
    for (const a of admins.docs) {
        await db().collection("notifications").add({
            userId: a.id, title: `New taka deposit ৳${amountBdt}`,
            message: `${user.displayName || "A user"} says they sent ৳${amountBdt} by ${method.title || method.type} (Txn ${transactionId}).`,
            type: "admin_deposit", link: "/admin/deposits", route: "/admin", read: false, createdAt: now(),
        });
    }
    return { id: ref.id, status: "pending" };
});

/** Admin: approve (credits the taka wallet, once) or reject with a reason */
exports.reviewBdtDeposit = onCall({ region: REGION }, async (request) => {
    const adminUser = await requireAdmin(request);
    const { depositId, decision, reason, amountBdt: correctedAmount } = request.data || {};
    if (!depositId || !["approve", "reject"].includes(decision)) throw new HttpsError("invalid-argument", "Missing decision.");
    const why = String(reason || "").trim().slice(0, 500);
    if (decision === "reject" && why.length < 5) throw new HttpsError("invalid-argument", "Tell them why (at least 5 characters).");

    const depRef = db().collection("bdt_deposits").doc(depositId);
    let result;
    await db().runTransaction(async (tx) => {
        const dep = await tx.get(depRef);
        if (!dep.exists) throw new HttpsError("not-found", "Deposit not found.");
        const d = dep.data();
        if (d.status !== "pending") throw new HttpsError("failed-precondition", `This deposit is already ${d.status}.`);
        if (decision === "reject") {
            tx.update(depRef, { status: "rejected", rejectReason: why, reviewedAt: now(), reviewedBy: adminUser.uid, reviewedByName: adminUser.name });
            result = { status: "rejected", uid: d.uid, amountBdt: d.amountBdt };
            return;
        }
        // The admin may credit what actually arrived (e.g. the sender paid a fee)
        const credit = correctedAmount != null ? round2(correctedAmount) : round2(d.amountBdt);
        if (!(credit > 0)) throw new HttpsError("invalid-argument", "Amount must be more than 0.");
        tx.update(depRef, { status: "approved", creditedBdt: credit, reviewedAt: now(), reviewedBy: adminUser.uid, reviewedByName: adminUser.name });
        tx.set(db().collection("users").doc(d.uid), { walletBdt: admin.firestore.FieldValue.increment(credit) }, { merge: true });
        tx.set(db().collection("wallet_transactions").doc(), {
            uid: d.uid, type: "bdt_deposit", amountBdt: credit, amountUsd: 0, feeBdt: 0, rate: null, refId: depositId, createdAt: now(),
        });
        result = { status: "approved", uid: d.uid, amountBdt: credit };
    });

    if (result.status === "approved") {
        await notify(result.uid, `৳${result.amountBdt} added to your taka wallet`, "Your deposit is confirmed. Convert it to dollars to shop on Reskindev.", "deposit_approved");
    } else {
        await notify(result.uid, "Deposit not confirmed", `We couldn't confirm your ৳${result.amountBdt} deposit. Reason: ${why}`, "deposit_rejected");
    }
    return { status: result.status };
});

/** Price check before converting (no changes) */
exports.quoteBdtToUsd = onCall({ region: REGION }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in first.");
    const s = await settings();
    const amountBdt = round2(request.data && request.data.amountBdt);
    const feeBdt = round2(amountBdt * s.convertFeePercent / 100);
    const amountUsd = Math.floor(((amountBdt - feeBdt) / s.bdtPerUsd) * 100) / 100;
    return { amountBdt, feeBdt, amountUsd, bdtPerUsd: s.bdtPerUsd, feePercent: s.convertFeePercent, rateMode: s.rateMode,
             rateUpdatedAt: s.rateUpdatedAt && s.rateUpdatedAt.toMillis ? s.rateUpdatedAt.toMillis() : null };
});

/** Person: taka → dollars, fee kept in taka. Rounds dollars down to the cent. */
exports.convertBdtToUsd = onCall({ region: REGION }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in first.");
    const uid = request.auth.uid;
    const s = await settings();
    if (!(s.bdtPerUsd > 0)) throw new HttpsError("unavailable", "Conversion is not set up yet.");
    const amountBdt = round2(request.data && request.data.amountBdt);
    if (!(amountBdt > 0)) throw new HttpsError("invalid-argument", "Enter how many taka to convert.");
    const feeBdt = round2(amountBdt * s.convertFeePercent / 100);
    const amountUsd = Math.floor(((amountBdt - feeBdt) / s.bdtPerUsd) * 100) / 100;
    if (amountUsd < 0.01) throw new HttpsError("invalid-argument", "That amount is too small to convert.");

    const userRef = db().collection("users").doc(uid);
    await db().runTransaction(async (tx) => {
        const u = (await tx.get(userRef)).data() || {};
        if (!isBangladesh(u)) throw new HttpsError("failed-precondition", "Taka conversion is for accounts in Bangladesh.");
        const have = round2(u.walletBdt);
        if (have + 1e-9 < amountBdt) throw new HttpsError("failed-precondition", `Your taka wallet has ৳${have.toFixed(2)}.`);
        tx.update(userRef, {
            walletBdt: round2(have - amountBdt),
            walletBalance: admin.firestore.FieldValue.increment(amountUsd),
        });
        tx.set(db().collection("wallet_transactions").doc(), {
            uid, type: "bdt_to_usd", amountBdt, amountUsd, feeBdt, rate: s.bdtPerUsd, feePercent: s.convertFeePercent, createdAt: now(),
        });
    });
    return { amountBdt, feeBdt, amountUsd, bdtPerUsd: s.bdtPerUsd };
});

/** Admin: rate, fee, limits and where people send money */
exports.saveBdtWalletSettings = onCall({ region: REGION }, async (request) => {
    await requireAdmin(request);
    const d = request.data || {};
    const rateMode = d.rateMode === "manual" ? "manual" : "live";
    let bdtPerUsd = Number(d.bdtPerUsd);
    const convertFeePercent = Number(d.convertFeePercent);
    if (rateMode === "live") {
        try { bdtPerUsd = await fetchLiveRate(); } catch (e) {
            const cur = (await db().collection("settings").doc("bdtWallet").get()).data() || {};
            bdtPerUsd = Number(cur.bdtPerUsd) || DEFAULTS.bdtPerUsd;
        }
    }
    if (!(bdtPerUsd > 1 && bdtPerUsd < 1000)) throw new HttpsError("invalid-argument", "Enter a sensible rate (taka per dollar).");
    if (!(convertFeePercent >= 0 && convertFeePercent <= 20)) throw new HttpsError("invalid-argument", "Fee must be between 0 and 20%.");
    const clean = (v, n = 120) => String(v || "").trim().slice(0, n);
    const methods = (Array.isArray(d.methods) ? d.methods : []).slice(0, 10).map((m, i) => ({
        id: clean(m.id, 40) || `m${Date.now()}${i}`,
        type: ["bank", "bkash", "nagad", "rocket"].includes(m.type) ? m.type : "bank",
        title: clean(m.title, 60), accountName: clean(m.accountName), accountNumber: clean(m.accountNumber, 60),
        bankName: clean(m.bankName), branch: clean(m.branch), routing: clean(m.routing, 30), note: clean(m.note, 300),
    })).filter((m) => m.accountNumber);
    await db().collection("settings").doc("bdtWallet").set({
        bdtPerUsd, rateMode, convertFeePercent, rateUpdatedAt: now(),
        minDepositBdt: Math.max(1, Number(d.minDepositBdt) || DEFAULTS.minDepositBdt),
        maxDepositBdt: Math.max(1, Number(d.maxDepositBdt) || DEFAULTS.maxDepositBdt),
        enabled: d.enabled !== false, methods, updatedAt: now(),
    }, { merge: false });
    return { ok: true, bdtPerUsd, rateMode };
});
