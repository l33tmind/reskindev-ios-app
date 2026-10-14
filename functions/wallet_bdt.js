/**
 * Taka (BDT) wallet for people in Bangladesh: deposit taka to the admin's bank / mobile banking,
 * the admin confirms it, then the person converts taka to the site's dollars (3% fee by default)
 * and spends those dollars from the normal wallet (users.walletBalance).
 *
 * Firestore (all money fields are written ONLY here; rules block clients):
 *   users/{uid}.walletBdt                 taka balance (number, 2 decimals)
 *   users/{uid}.walletBalance             dollar balance (existing)
 *   settings/bdtWallet                    { bdtPerUsd, rateMode: "live"|"manual" (live = refreshBdtRate every hour), convertFeePercent, minDepositBdt, maxDepositBdt, enabled,
 *                                           methods: [{ id, type: "bank"|"bkash"|"nagad"|"rocket", title,
 *                                                       accountName, accountNumber, bankName?, branch?, routing?, note? }] }
 *                                         (admins edit it from the admin panel; anyone signed in can read)
 *   bdt_deposits/{id}                     { uid, name, email, amountBdt, methodId, methodTitle, senderAccount,
 *                                           purpose: "wallet"|"order"|"pro", orderId?, orderTitle?, plan?, expectedBdt?, rateAtRequest,
 *                                           transactionId, receiptPath?, status: "pending"|"approved"|"rejected",
 *                                           createdAt, reviewedAt?, reviewedBy?, rejectReason?, creditedBdt? }
 *   wallet_transactions/{id}              every balance change: { uid, type: "bdt_deposit"|"bdt_to_usd"|"bdt_adjust",
 *                                           amountBdt, amountUsd, feeBdt, rate, refId, createdAt }
 * Receipts: Storage deposits/{uid}/... (owner + admins only).
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { PLANS, grantPro } = require("./pro_core");

const REGION = "asia-south1";
const db = () => admin.firestore();
const now = () => admin.firestore.FieldValue.serverTimestamp();
const round2 = (n) => Math.round((Number(n) || 0) * 100) / 100;

const DEFAULTS = {
    bdtPerUsd: 122, rateMode: "live", convertFeePercent: 3, minDepositBdt: 100, maxDepositBdt: 500000, enabled: true, methods: [],
    // Sellers paid in taka withdraw to these (admin chooses which are on), from this amount up
    withdrawMethods: ["bkash", "nagad", "rocket", "bank"], minWithdrawBdt: 500,
    // Reskindev Pro paid in taka
    proMonthlyBdt: 999, proYearlyBdt: 9999,
};
const CLEARANCE_MS = 15 * 86400000; // same 15 days as dollar earnings

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

/** Every hour: keep the live rate fresh (the last good rate stays if the source is down) */
exports.refreshBdtRate = onSchedule({ schedule: "every 60 minutes", region: REGION }, async () => {
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

    // What the money is for: topping up the taka wallet, paying one order, or buying Pro
    const purpose = ["order", "pro"].includes(d.purpose) ? d.purpose : "wallet";
    let orderId = null, plan = null, expectedBdt = null, orderTitle = null;
    if (purpose === "order") {
        orderId = String(d.orderId || "");
        const os = orderId ? await db().collection("orders").doc(orderId).get() : null;
        if (!os || !os.exists) throw new HttpsError("not-found", "Order not found.");
        const o = os.data();
        if ((o.userId || o.clientUid) !== uid) throw new HttpsError("permission-denied", "This isn't your order.");
        if (!["pending_payment", "pending"].includes(o.status)) throw new HttpsError("failed-precondition", "This order is already paid.");
        expectedBdt = Math.ceil(Number(o.price) * s.bdtPerUsd);
        orderTitle = o.gigTitle || "";
    } else if (purpose === "pro") {
        plan = PLANS[d.plan] ? d.plan : null;
        if (!plan) throw new HttpsError("invalid-argument", "Choose monthly or yearly.");
        expectedBdt = plan === "yearly" ? (Number(s.proYearlyBdt) || 9999) : (Number(s.proMonthlyBdt) || 999);
    }
    if (purpose === "wallet") {
        if (!(amountBdt >= s.minDepositBdt)) throw new HttpsError("invalid-argument", `The minimum deposit is ৳${s.minDepositBdt}.`);
        if (amountBdt > s.maxDepositBdt) throw new HttpsError("invalid-argument", `The maximum deposit is ৳${s.maxDepositBdt}.`);
    } else if (!(amountBdt >= expectedBdt)) {
        throw new HttpsError("invalid-argument", `Please send at least ৳${expectedBdt}.`);
    }
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
        purpose, orderId, orderTitle, plan, expectedBdt, rateAtRequest: s.bdtPerUsd,
        senderAccount, transactionId, receiptPath: receiptPath || null,
        status: "pending", createdAt: now(),
    });

    const admins = await db().collection("users").where("role", "==", "admin").get();
    for (const a of admins.docs) {
        await db().collection("notifications").add({
            userId: a.id, title: purpose === "order" ? `Order payment ৳${amountBdt} to check` : purpose === "pro" ? `Pro (${plan}) payment ৳${amountBdt} to check` : `New taka deposit ৳${amountBdt}`,
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
        if (d.purpose === "order" && d.orderId) {
            // Bank payment for one order: the order becomes paid in taka (nothing goes to the wallet)
            const orderRef = db().collection("orders").doc(d.orderId);
            const os = await tx.get(orderRef);
            if (!os.exists) throw new HttpsError("not-found", "The order no longer exists.");
            const o = os.data();
            if (!["pending_payment", "pending"].includes(o.status)) {
                // Already paid another way: keep the money as wallet credit instead
                tx.set(db().collection("users").doc(d.uid), { walletBdt: admin.firestore.FieldValue.increment(credit) }, { merge: true });
                tx.set(db().collection("wallet_transactions").doc(), {
                    uid: d.uid, type: "bdt_deposit", amountBdt: credit, amountUsd: 0, feeBdt: 0, rate: null, refId: depositId, createdAt: now(),
                });
                result = { status: "approved", uid: d.uid, amountBdt: credit, credited: "wallet" };
                return;
            }
            tx.update(orderRef, {
                status: "requirements", paidCurrency: "BDT", amountBdt: credit,
                bdtRate: d.rateAtRequest || null, paymentMethod: "taka_bank", paidAt: now(), updatedAt: now(),
            });
            tx.set(db().collection("wallet_transactions").doc(), {
                uid: d.uid, type: "order_payment", amountBdt: -credit, amountUsd: 0, feeBdt: 0, rate: d.rateAtRequest || null,
                refId: d.orderId, via: "bank", createdAt: now(),
            });
            result = { status: "approved", uid: d.uid, amountBdt: credit, purpose: "order", order: o, orderId: d.orderId };
            return;
        }
        if (d.purpose === "pro" && d.plan) {
            result = { status: "approved", uid: d.uid, amountBdt: credit, purpose: "pro", plan: d.plan };
            tx.set(db().collection("pro_payments").doc(), {
                uid: d.uid, plan: d.plan, amountBdt: credit, source: "taka_bank", depositId, createdAt: now(),
            });
            return;
        }
        tx.set(db().collection("users").doc(d.uid), { walletBdt: admin.firestore.FieldValue.increment(credit) }, { merge: true });
        tx.set(db().collection("wallet_transactions").doc(), {
            uid: d.uid, type: "bdt_deposit", amountBdt: credit, amountUsd: 0, feeBdt: 0, rate: null, refId: depositId, createdAt: now(),
        });
        result = { status: "approved", uid: d.uid, amountBdt: credit };
    });

    if (result.status === "approved" && result.purpose === "order") {
        await postOrderCard(result.order, result.orderId, "payment_verified",
            `Payment received: ৳${result.amountBdt} by bank transfer. The seller can start now.`);
        await notify(result.uid, "Payment confirmed", `We received ৳${result.amountBdt}. Your order is paid and the seller can start.`, "deposit_approved");
    } else if (result.status === "approved" && result.purpose === "pro") {
        const u = (await db().collection("users").doc(result.uid).get()).data() || {};
        const current = u.pro && u.pro.expiresAt ? u.pro.expiresAt.toMillis() : 0;
        await grantPro(result.uid, {
            plan: result.plan, source: "wallet", productId: PLANS[result.plan].productId,
            expiresAtMs: Math.max(Date.now(), current) + PLANS[result.plan].days * 86400000, autoRenew: false,
        });
    } else if (result.status === "approved") {
        await notify(result.uid, `৳${result.amountBdt} added to your taka wallet`, "Your deposit is confirmed. You can pay for services and Pro with it.", "deposit_approved");
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
    // Turned off: taka is spent as taka (orders, Pro), there is no taka→dollar conversion any more
    throw new HttpsError("failed-precondition", "Taka can't be converted to dollars. Pay for services in taka directly.");
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
        withdrawMethods: (Array.isArray(d.withdrawMethods) ? d.withdrawMethods : DEFAULTS.withdrawMethods)
            .filter((m) => ["bkash", "nagad", "rocket", "bank"].includes(m)),
        minWithdrawBdt: Math.max(1, Number(d.minWithdrawBdt) || DEFAULTS.minWithdrawBdt),
        proMonthlyBdt: Math.max(1, Number(d.proMonthlyBdt) || DEFAULTS.proMonthlyBdt),
        proYearlyBdt: Math.max(1, Number(d.proYearlyBdt) || DEFAULTS.proYearlyBdt),
    }, { merge: false });
    return { ok: true, bdtPerUsd, rateMode };
});

// ---------------- Paying for an order in taka ----------------

/** Find the order's chat and post a system card (the chat push function turns it into notifications) */
async function postOrderCard(order, orderId, actionType, text) {
    const chats = await db().collection("conversations").where("orderId", "==", orderId).limit(1).get();
    if (chats.empty) return;
    const ref = chats.docs[0].ref;
    await ref.collection("messages").add({
        type: "system_notification", actionType, text, orderId, gigTitle: order.gigTitle || "",
        price: Number(order.price) || 0, senderId: "system", createdAt: now(), read: false,
    });
    await ref.update({ lastMessage: text, updatedAt: now() });
}

/**
 * Buyer pays a placed order (status pending_payment) from the taka wallet.
 * Dollar price × current rate, rounded up to whole taka. The order becomes paid right away.
 */
exports.payOrderWithTaka = onCall({ region: REGION }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in first.");
    const uid = request.auth.uid;
    const orderId = request.data && request.data.orderId;
    if (!orderId) throw new HttpsError("invalid-argument", "Missing order.");
    const s = await settings();
    const orderRef = db().collection("orders").doc(orderId);
    const userRef = db().collection("users").doc(uid);
    let paid;
    await db().runTransaction(async (tx) => {
        const [os, us] = await Promise.all([tx.get(orderRef), tx.get(userRef)]);
        if (!os.exists) throw new HttpsError("not-found", "Order not found.");
        const o = os.data();
        if ((o.userId || o.clientUid) !== uid) throw new HttpsError("permission-denied", "This isn't your order.");
        if (!["pending_payment", "pending"].includes(o.status)) throw new HttpsError("failed-precondition", "This order is already paid.");
        const u = us.data() || {};
        if (!isBangladesh(u)) throw new HttpsError("failed-precondition", "Taka payments are for accounts in Bangladesh.");
        const amountBdt = Math.ceil(Number(o.price) * s.bdtPerUsd);
        const have = round2(u.walletBdt);
        if (have < amountBdt) throw new HttpsError("failed-precondition", `This order costs ৳${amountBdt}. Your taka wallet has ৳${have.toFixed(2)}.`);
        tx.update(userRef, { walletBdt: round2(have - amountBdt) });
        tx.update(orderRef, {
            status: "requirements", paidCurrency: "BDT", amountBdt, bdtRate: s.bdtPerUsd,
            paymentMethod: "taka_wallet", paidAt: now(), updatedAt: now(),
        });
        tx.set(db().collection("wallet_transactions").doc(), {
            uid, type: "order_payment", amountBdt: -amountBdt, amountUsd: 0, feeBdt: 0, rate: s.bdtPerUsd, refId: orderId, createdAt: now(),
        });
        paid = { order: o, amountBdt };
    });
    await postOrderCard(paid.order, orderId, "payment_verified",
        `Payment received: ৳${paid.amountBdt} from the taka wallet. The seller can start now.`);
    return { amountBdt: paid.amountBdt, status: "requirements" };
});

// ---------------- Sellers' taka earnings and withdrawals ----------------

/** Taka earned from completed orders paid in taka, after the platform fee; cleared after 15 days */
async function takaEarnings(uid) {
    const g = (await db().collection("settings").doc("global").get()).data() || {};
    const feePct = Number(g.platformFee) || 10;
    const orders = await db().collection("orders").where("authorId", "==", uid).where("paidCurrency", "==", "BDT").get();
    let total = 0, cleared = 0;
    for (const d of orders.docs) {
        const o = d.data();
        if (o.status !== "completed") continue;
        const usdPaid = Number(o.price) || 0;
        // A dispute split pays the seller part of the price: same share of the taka
        const usdSeller = o.disputeResolution && o.disputeResolution.sellerAmount != null ? Number(o.disputeResolution.sellerAmount) || 0 : usdPaid;
        const bdt = usdPaid > 0 ? (Number(o.amountBdt) || 0) * (usdSeller / usdPaid) : 0;
        const share = bdt * (1 - feePct / 100);
        total += share;
        const done = o.completedAt && o.completedAt.toMillis ? o.completedAt.toMillis() : 0;
        if (done && Date.now() - done >= CLEARANCE_MS) cleared += share;
    }
    return { total: round2(total), cleared: round2(cleared), feePct };
}

exports.getTakaEarnings = onCall({ region: REGION }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in first.");
    const uid = request.auth.uid;
    const e = await takaEarnings(uid);
    const u = (await db().collection("users").doc(uid).get()).data() || {};
    const withdrawn = round2(u.bdtWithdrawnTotal);
    const s = await settings();
    return { ...e, withdrawn, available: round2(Math.max(0, e.cleared - withdrawn)), pending: round2(e.total - e.cleared),
             minWithdrawBdt: s.minWithdrawBdt, withdrawMethods: s.withdrawMethods };
});

exports.requestBdtWithdrawal = onCall({ region: REGION }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in first.");
    const uid = request.auth.uid;
    const d = request.data || {};
    const s = await settings();
    const amountBdt = round2(d.amountBdt);
    const method = String(d.method || "");
    const accountNumber = String(d.accountNumber || "").trim().slice(0, 60);
    const accountName = String(d.accountName || "").trim().slice(0, 120);
    const bankName = String(d.bankName || "").trim().slice(0, 120);
    const branch = String(d.branch || "").trim().slice(0, 120);
    if (!(s.withdrawMethods || []).includes(method)) throw new HttpsError("invalid-argument", "Choose a withdrawal method.");
    if (!(amountBdt >= s.minWithdrawBdt)) throw new HttpsError("invalid-argument", `The minimum withdrawal is ৳${s.minWithdrawBdt}.`);
    if (accountNumber.length < 6) throw new HttpsError("invalid-argument", "Enter the account / wallet number.");
    if (!accountName) throw new HttpsError("invalid-argument", "Enter the account holder's name.");
    if (method === "bank" && !bankName) throw new HttpsError("invalid-argument", "Enter the bank name.");

    const e = await takaEarnings(uid);
    const userRef = db().collection("users").doc(uid);
    const wRef = db().collection("bdt_withdrawals").doc();
    await db().runTransaction(async (tx) => {
        const u = (await tx.get(userRef)).data() || {};
        if (!isBangladesh(u)) throw new HttpsError("failed-precondition", "Taka withdrawals are for accounts in Bangladesh.");
        const withdrawn = round2(u.bdtWithdrawnTotal);
        const available = round2(e.cleared - withdrawn);
        if (amountBdt > available) throw new HttpsError("failed-precondition", `You can withdraw up to ৳${Math.max(0, available).toFixed(2)} now.`);
        tx.set(userRef, { bdtWithdrawnTotal: round2(withdrawn + amountBdt) }, { merge: true });
        tx.set(wRef, {
            uid, name: u.displayName || u.name || "", email: u.email || "",
            amountBdt, method, accountNumber, accountName, bankName: bankName || null, branch: branch || null,
            status: "pending", createdAt: now(),
        });
    });
    const admins = await db().collection("users").where("role", "==", "admin").get();
    for (const a of admins.docs) {
        await db().collection("notifications").add({
            userId: a.id, title: `Taka withdrawal ৳${amountBdt}`,
            message: `Send ৳${amountBdt} by ${method} to ${accountNumber} (${accountName}).`,
            type: "admin_withdrawal", link: "/admin/deposits?tab=withdrawals", route: "/admin", read: false, createdAt: now(),
        });
    }
    return { id: wRef.id, status: "pending" };
});

/** Admin: mark paid (with the transaction ID) or reject (the amount goes back to the seller's available taka) */
exports.reviewBdtWithdrawal = onCall({ region: REGION }, async (request) => {
    const adminUser = await requireAdmin(request);
    const { withdrawalId, decision, txnId, reason } = request.data || {};
    if (!withdrawalId || !["paid", "reject"].includes(decision)) throw new HttpsError("invalid-argument", "Missing decision.");
    const t = String(txnId || "").trim().slice(0, 80);
    const why = String(reason || "").trim().slice(0, 500);
    if (decision === "paid" && t.length < 4) throw new HttpsError("invalid-argument", "Enter the bKash / Nagad / bank transaction ID.");
    if (decision === "reject" && why.length < 5) throw new HttpsError("invalid-argument", "Tell them why (at least 5 characters).");
    const ref = db().collection("bdt_withdrawals").doc(withdrawalId);
    let w;
    await db().runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists) throw new HttpsError("not-found", "Withdrawal not found.");
        w = snap.data();
        if (w.status !== "pending") throw new HttpsError("failed-precondition", `Already ${w.status}.`);
        if (decision === "paid") {
            tx.update(ref, { status: "paid", txnId: t, paidAt: now(), reviewedBy: adminUser.uid, reviewedByName: adminUser.name });
            tx.set(db().collection("wallet_transactions").doc(), {
                uid: w.uid, type: "bdt_withdrawal", amountBdt: -w.amountBdt, amountUsd: 0, feeBdt: 0, rate: null, refId: withdrawalId, createdAt: now(),
            });
        } else {
            tx.update(ref, { status: "rejected", rejectReason: why, reviewedAt: now(), reviewedBy: adminUser.uid, reviewedByName: adminUser.name });
            tx.set(db().collection("users").doc(w.uid), { bdtWithdrawnTotal: admin.firestore.FieldValue.increment(-w.amountBdt) }, { merge: true });
        }
    });
    await notify(w.uid,
        decision === "paid" ? `৳${w.amountBdt} sent to your ${w.method}` : "Withdrawal not sent",
        decision === "paid" ? `Transaction ID: ${t}` : `Reason: ${why}. The amount is available to withdraw again.`,
        decision === "paid" ? "withdrawal_paid" : "withdrawal_rejected");
    return { status: decision === "paid" ? "paid" : "rejected" };
});

