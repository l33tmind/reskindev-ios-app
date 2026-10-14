/**
 * Identity verification (blue tick) for Reskindev Pro members, and priority support.
 *
 * verifications/{uid} (one per person; written ONLY here, rules block client writes):
 *   { uid, name, email, status: "pending" | "approved" | "rejected",
 *     legalName, dateOfBirth ("YYYY-MM-DD"), idType: "nid" | "passport" | "driving_license",
 *     country, address: { line1, city, postcode },
 *     files: { idFront, idBack?, selfie }   // Storage paths under verification/{uid}/ (private: owner + admins)
 *     isPro, submittedAt, reviewedAt?, reviewedBy?, rejectReason?, history: [...] }
 * Approving sets users/{uid}.verified = true (+ verifiedAt); rejecting or revoking sets it false.
 *
 * Support tickets from Pro members get priority: true (admins can also set it by hand).
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

const REGION = "asia-south1";
const ID_TYPES = ["nid", "passport", "driving_license"];
const db = () => admin.firestore();
const now = () => admin.firestore.FieldValue.serverTimestamp();

const isProData = (u) => !!(u && u.pro && u.pro.active && u.pro.expiresAt && u.pro.expiresAt.toMillis() > Date.now());

async function requireAdmin(request) {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in first.");
    const me = await db().collection("users").doc(request.auth.uid).get();
    if (!me.exists || me.data().role !== "admin") throw new HttpsError("permission-denied", "Admins only.");
    return { uid: request.auth.uid, name: me.data().displayName || me.data().name || "Admin" };
}

async function notify(uid, title, message, type) {
    await db().collection("notifications").add({
        userId: uid, title, message, type,
        link: "/profile/verification", route: "/verification",
        read: false, createdAt: now(),
    });
}

/** Person applies (or re-applies after a rejection). Pro members only. */
exports.submitVerification = onCall({ region: REGION }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in first.");
    const uid = request.auth.uid;
    const userSnap = await db().collection("users").doc(uid).get();
    const user = userSnap.data() || {};
    if (!isProData(user)) throw new HttpsError("permission-denied", "Identity verification is part of Reskindev Pro. Subscribe first.");
    if (user.verified === true) throw new HttpsError("already-exists", "You're already verified.");

    const d = request.data || {};
    const clean = (v, max = 200) => String(v || "").trim().slice(0, max);
    const legalName = clean(d.legalName, 120);
    const dateOfBirth = clean(d.dateOfBirth, 10);
    const idType = clean(d.idType, 20);
    const country = clean(d.country, 80);
    const address = { line1: clean(d.address && d.address.line1), city: clean(d.address && d.address.city, 80), postcode: clean(d.address && d.address.postcode, 20) };
    const files = { idFront: clean(d.files && d.files.idFront, 300), idBack: clean(d.files && d.files.idBack, 300), selfie: clean(d.files && d.files.selfie, 300) };

    if (legalName.length < 3) throw new HttpsError("invalid-argument", "Enter your full name as it is on your ID.");
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dateOfBirth)) throw new HttpsError("invalid-argument", "Enter your date of birth.");
    if (!ID_TYPES.includes(idType)) throw new HttpsError("invalid-argument", "Choose the type of ID.");
    if (!country) throw new HttpsError("invalid-argument", "Choose your country.");
    if (!address.line1 || !address.city) throw new HttpsError("invalid-argument", "Enter your address and city.");
    // Files must be this person's own uploads
    const own = (p) => p.startsWith(`verification/${uid}/`);
    if (!files.idFront || !own(files.idFront)) throw new HttpsError("invalid-argument", "Add a photo of the front of your ID.");
    if (!files.selfie || !own(files.selfie)) throw new HttpsError("invalid-argument", "Add a selfie holding your ID.");
    if (files.idBack && !own(files.idBack)) throw new HttpsError("invalid-argument", "Invalid ID back photo.");
    if (idType !== "passport" && !files.idBack) throw new HttpsError("invalid-argument", "Add a photo of the back of your ID.");
    const bucket = admin.storage().bucket();
    for (const p of [files.idFront, files.idBack, files.selfie].filter(Boolean)) {
        const [exists] = await bucket.file(p).exists();
        if (!exists) throw new HttpsError("failed-precondition", "A photo didn't finish uploading. Please add it again.");
    }

    const ref = db().collection("verifications").doc(uid);
    const before = (await ref.get()).data();
    if (before && before.status === "pending") throw new HttpsError("already-exists", "Your request is already being reviewed.");

    await ref.set({
        uid, name: user.displayName || user.name || legalName, email: user.email || "",
        status: "pending", legalName, dateOfBirth, idType, country, address,
        files: { idFront: files.idFront, idBack: files.idBack || null, selfie: files.selfie },
        isPro: true, submittedAt: now(), reviewedAt: null, reviewedBy: null, rejectReason: null,
        history: admin.firestore.FieldValue.arrayUnion({ status: "pending", at: Date.now() }),
    }, { merge: true });
    await db().collection("users").doc(uid).set({ verificationStatus: "pending" }, { merge: true });

    // Tell the admins
    const admins = await db().collection("users").where("role", "==", "admin").get();
    for (const a of admins.docs) {
        await db().collection("notifications").add({
            userId: a.id, title: "New verification request",
            message: `${legalName} (Pro) sent ID photos for the blue tick.`,
            type: "admin_verification", link: "/admin/verifications", route: "/admin", read: false, createdAt: now(),
        });
    }
    return { status: "pending" };
});

/** Admin: approve, reject (with a reason) or revoke a blue tick */
exports.reviewVerification = onCall({ region: REGION }, async (request) => {
    const adminUser = await requireAdmin(request);
    const { uid, decision, reason } = request.data || {};
    if (!uid || !["approve", "reject", "revoke"].includes(decision)) throw new HttpsError("invalid-argument", "Missing decision.");
    const ref = db().collection("verifications").doc(uid);
    const snap = await ref.get();
    if (!snap.exists && decision !== "revoke") throw new HttpsError("not-found", "No request from this person.");
    const why = String(reason || "").trim().slice(0, 500);
    if (decision === "reject" && why.length < 5) throw new HttpsError("invalid-argument", "Tell them why (at least 5 characters), so they can fix it.");

    const status = decision === "approve" ? "approved" : decision === "reject" ? "rejected" : "revoked";
    await ref.set({
        status, reviewedAt: now(), reviewedBy: adminUser.uid, reviewedByName: adminUser.name,
        rejectReason: decision === "approve" ? null : (why || null),
        history: admin.firestore.FieldValue.arrayUnion({ status, at: Date.now(), by: adminUser.uid, reason: why || null }),
    }, { merge: true });
    await db().collection("users").doc(uid).set({
        verified: decision === "approve",
        verificationStatus: status,
        ...(decision === "approve" ? { verifiedAt: now() } : {}),
    }, { merge: true });

    if (decision === "approve") {
        await notify(uid, "You're verified ✓", "Your identity is confirmed. The blue tick now shows next to your name.", "verification_approved");
    } else if (decision === "reject") {
        await notify(uid, "Verification needs another look", `Please send new photos. Reason: ${why}`, "verification_rejected");
    } else {
        await notify(uid, "Blue tick removed", why ? `Reason: ${why}` : "Contact support if you have questions.", "verification_revoked");
    }
    return { status };
});

/** Pro members' tickets go to the front of the queue */
exports.onSupportTicketCreated = onDocumentCreated({ document: "support_tickets/{ticketId}", region: REGION }, async (event) => {
    const t = event.data ? event.data.data() : null;
    if (!t) return null;
    const uid = t.reportedByUid || t.userId || t.uid || t.createdBy;
    if (!uid) return null;
    const u = (await db().collection("users").doc(uid).get()).data();
    if (isProData(u)) await event.data.ref.update({ priority: true, isPro: true });
    return null;
});

/** Admin: mark any ticket priority (or not) by hand */
exports.setTicketPriority = onCall({ region: REGION }, async (request) => {
    await requireAdmin(request);
    const { ticketId, priority } = request.data || {};
    if (!ticketId) throw new HttpsError("invalid-argument", "Missing ticket.");
    await db().collection("support_tickets").doc(ticketId).update({ priority: !!priority });
    return { priority: !!priority };
});
