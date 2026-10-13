const { onDocumentWritten, onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Trigger: Whenever a review is created, updated, or deleted.
 * Action: Recalculates the average rating and reviewCount for the parent service/gig.
 */
exports.updateGigRating = onDocumentWritten("services/{gigId}/reviews/{reviewId}", async (event) => {
    const gigId = event.params.gigId;
    const db = admin.firestore();
    
    // Fetch all reviews for this specific gig
    const reviewsSnapshot = await db.collection(`services/${gigId}/reviews`).get();
    
    let totalRating = 0;
    let reviewCount = 0;

    reviewsSnapshot.forEach((doc) => {
        const data = doc.data();
        // Assume rating is stored as a number, if string try to parse it
        const rating = Number(data.rating);
        if (!isNaN(rating)) {
            totalRating += rating;
            reviewCount++;
        }
    });

    const averageRating = reviewCount > 0 ? (totalRating / reviewCount) : 0;
    
    // Update the parent gig document with the new aggregated data
    await db.collection("services").doc(gigId).update({
        rating: Number(averageRating.toFixed(1)),
        averageRating: Number(averageRating.toFixed(1)),
        reviewCount: reviewCount
    });

    console.log(`Successfully updated gig ${gigId}: new rating ${averageRating.toFixed(1)} based on ${reviewCount} reviews.`);
    return null;
});

/**
 * Order events that appear in an order chat as system messages.
 * `to` says who gets the push + in-app notification, so nobody is notified about their own action.
 * `type` picks the icon in the app's Notifications screen.
 */
const money = (n) => (n == null || isNaN(n) ? "" : `$${Number(n).toFixed(Number(n) % 1 === 0 ? 0 : 2)}`);

const ORDER_EVENTS = {
    // No notification here: onOrderCreated already tells buyer and seller about every new order,
    // on every platform. Notifying here too gave each person the same news twice.
    order_placed: { type: "order" },
    payment_verified: {
        type: "payment",
        seller: (o) => ({ title: "Payment secured", body: `${o.gigTitle} · funds are held safely, you can start` }),
        // The buyer already gave the project details when ordering; nothing more is needed from them
        buyer: (o) => ({ title: "Payment secured", body: `${o.gigTitle} · the seller can start now` }),
    },
    requirements_submitted: {
        type: "requirements",
        seller: (o) => ({ title: "Requirements received", body: `${o.gigTitle} · review them and start work` }),
    },
    order_started: {
        type: "started",
        buyer: (o) => ({ title: "Work has started", body: `${o.gigTitle}${o.deliveryDays ? " · due in " + o.deliveryDays + " days" : ""}` }),
    },
    order_delivered: {
        type: "delivery",
        buyer: (o) => ({ title: "Your delivery is ready", body: `${o.gigTitle} · review it and approve or ask for a revision` }),
    },
    revision_requested: {
        type: "revision",
        seller: (o) => ({ title: "Revision requested", body: `${o.gigTitle} · the buyer needs a few changes` }),
    },
    order_completed: {
        type: "completed",
        seller: (o) => ({ title: "Order completed", body: `${o.gigTitle}${o.price ? " · " + money(o.price) + " is yours" : ""}` }),
        buyer: (o) => ({ title: "Order completed", body: `${o.gigTitle} · tell others how it went with a review` }),
    },
    reviews_published: {
        type: "review",
        seller: (o) => ({ title: "Reviews published", body: `${o.gigTitle}` }),
        buyer: (o) => ({ title: "Reviews published", body: `${o.gigTitle}` }),
    },
};

/**
 * One in-app notification, in the shared `notifications` collection that the website bell and the
 * Vision Pro app already read (the Flutter app reads it too). `link` is the website page, `route` the app page.
 */
async function saveNotification(db, uid, { title, message, type, chatId, orderId, orderNumber, invoiceNumber, route, link }) {
    await db.collection("notifications").add({
        userId: uid,
        title, message, type,
        link: link || (chatId ? `/inbox?chat=${chatId}` : "/profile/orders"),
        route: route || (chatId ? `/chat/${chatId}` : "/my-orders"),
        chatId: chatId || null,
        orderId: orderId || null,
        orderNumber: orderNumber || "",
        invoiceNumber: invoiceNumber || "",
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}

async function sendToUser(db, uid, { title, subtitle, body, route, data }) {
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) return;
    const userData = userDoc.data();
    // fcmToken = the iOS app's device; fcmTokens = extra devices (Vision Pro)
    const tokens = [...new Set([userData.fcmToken, ...(userData.fcmTokens || [])].filter(Boolean))];
    for (const token of tokens) {
        try {
            await admin.messaging().send({
                notification: { title, body },
                data: { route, click_action: "FLUTTER_NOTIFICATION_CLICK", ...data },
                // iOS shows 2 lines in the banner; press and hold (or pull down) to read the whole text
                apns: { payload: { aps: { alert: { title, ...(subtitle ? { subtitle } : {}), body }, sound: "default" } } },
                android: {
                    notification: {
                        sound: "default",
                        channelId: "high_importance_channel",
                        priority: "high",
                    },
                },
                token,
            });
        } catch (error) {
            console.error(`Error sending push notification to user ${uid}:`, error);
            // Drop extra-device tokens that no longer exist (app deleted / signed out)
            if (error.code === "messaging/registration-token-not-registered" && token !== userData.fcmToken) {
                await userDoc.ref.update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(token) });
            }
        }
    }
}

/**
 * Every admin gets it: bell + push in the iOS / Android app (route opens the app's admin dashboard),
 * and the website bell links to the admin page. `skipUid` = the admin who caused it, if any.
 */
async function notifyAdmins(db, { title, body, type, link, data, skipUid }) {
    const admins = await db.collection("users").where("role", "==", "admin").get();
    for (const doc of admins.docs) {
        if (doc.id === skipUid) continue;
        await saveNotification(db, doc.id, { title, message: body, type, route: "/admin", link });
        await sendToUser(db, doc.id, { title, body, route: "/admin", data: data || {} });
    }
}

/**
 * Trigger: Whenever a new message is added to a conversation.
 * Action: sends a push notification AND saves it to the user's in-app notifications.
 *  - Normal chat message  -> the other person ("Robius", the text)
 *  - Offer                -> the other person
 *  - Order event (system) -> only the person who needs to act, with order number + invoice number
 */
exports.sendChatPushNotification = onDocumentCreated("conversations/{chatId}/messages/{messageId}", async (event) => {
    const snap = event.data;
    if (!snap) return;

    const messageData = snap.data();
    const senderId = messageData.senderId;
    const chatId = event.params.chatId;
    const route = `/chat/${chatId}`;

    const db = admin.firestore();
    const chatDoc = await db.collection("conversations").doc(chatId).get();
    if (!chatDoc.exists) return;
    const chatData = chatDoc.data();
    const participants = chatData.participants || [];

    // ── Order events ────────────────────────────────────────────
    if (senderId === "system") {
        const spec = ORDER_EVENTS[messageData.actionType];
        if (!spec) return null;

        const orderId = messageData.orderId || chatData.orderId;
        let order = {};
        if (orderId) {
            let orderDoc = await db.collection("orders").doc(orderId).get();
            // The invoice number is assigned a moment after the order is created
            if (orderDoc.exists && !orderDoc.data().invoiceNumber && messageData.actionType === "order_placed") {
                await new Promise((r) => setTimeout(r, 2500));
                orderDoc = await db.collection("orders").doc(orderId).get();
            }
            if (orderDoc.exists) order = orderDoc.data();
        }

        const buyerId = order.clientUid || chatData.clientId || participants[0];
        const sellerId = order.authorId || chatData.freelancerId || participants.find((p) => p !== buyerId);
        const gigTitle = order.gigTitle || messageData.gigTitle || "your order";
        const price = order.price != null ? order.price : messageData.price;
        const ctx = { gigTitle, price, deliveryDays: order.deliveryDays };
        const orderNo = orderId ? `#${orderId.slice(-6).toUpperCase()}` : "";
        const invoiceNo = order.invoiceNumber || "";

        for (const [role, uid] of [["buyer", buyerId], ["seller", sellerId]]) {
            if (!uid || !spec[role]) continue;
            const { title, body: summary } = spec[role](ctx);
            // Requirements, delivery and revision notes: send what the person actually wrote (up to 400 characters)
            const noteTypes = ["requirements_submitted", "order_delivered", "revision_requested"];
            let note = noteTypes.includes(messageData.actionType) ? String(messageData.text || "").trim() : "";
            if (note.length > 400) note = note.slice(0, 397) + "...";
            const body = note || summary;
            const pushTitle = orderNo ? `${title} · ${orderNo}` : title;
            const pushBody = invoiceNo ? `${body}\n${invoiceNo}` : body;

            await saveNotification(db, uid, {
                title, message: body, type: spec.type, chatId, orderId,
                orderNumber: orderNo, invoiceNumber: invoiceNo,
            });
            await sendToUser(db, uid, { title: pushTitle, subtitle: gigTitle, body: pushBody, route, data: { orderId: orderId || "" } });
        }
        return null;
    }

    // ── Normal chat messages and offers ─────────────────────────
    const recipientId = participants.find((id) => id !== senderId);
    if (!recipientId) return null;

    let title = messageData.senderName || "New message";
    let body = messageData.text || "You received a new message.";
    if (messageData.type === "offer") {
        title = `${messageData.senderName || "Seller"} sent you an offer`;
        body = [messageData.offerPrice != null ? money(messageData.offerPrice) : "", messageData.offerDays ? `${messageData.offerDays} days` : ""].filter(Boolean).join(" · ") || body;
    } else if (messageData.type === "image" || messageData.imageUrl) {
        body = body || "Sent a photo";
    }
    if (chatData.orderId) title = `${title} · #${String(chatData.orderId).slice(-6).toUpperCase()}`;

    await sendToUser(db, recipientId, { title, body, route, data: {} });
    return null;
});

/**
 * Callable: the other side accepts a cancellation request.
 * Cancels the order and refunds the buyer's wallet with the Admin SDK (clients can't write another user's balance).
 * Used by the Vision Pro app; same job as the website's processMutualCancellation server action.
 */
exports.processMutualCancellation = onCall(async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Please sign in.");
    const orderId = request.data && request.data.orderId;
    if (!orderId) throw new HttpsError("invalid-argument", "Missing orderId.");

    const db = admin.firestore();
    const orderRef = db.collection("orders").doc(orderId);

    const result = await db.runTransaction(async (tx) => {
        const snap = await tx.get(orderRef);
        if (!snap.exists) throw new HttpsError("not-found", "Order not found.");
        const order = snap.data();

        if (order.status === "cancelled" || order.status === "completed") {
            throw new HttpsError("failed-precondition", "Order is already completed or cancelled.");
        }
        const buyerId = order.userId || order.clientUid;
        const sellerId = order.freelancerId || order.authorId;
        // Only the side that did NOT ask can accept
        const allowed =
            (order.status === "cancel_requested_by_buyer" && uid === sellerId) ||
            (order.status === "cancel_requested_by_freelancer" && uid === buyerId);
        if (!allowed) throw new HttpsError("permission-denied", "You can't accept this cancellation.");

        // Unpaid orders (still pending_payment when the request was made) get no refund
        const wasPaid = order.statusBeforeCancel !== "pending_payment";
        const refund = wasPaid ? (Number(order.price) || 0) : 0;

        tx.update(orderRef, {
            status: "cancelled",
            cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            refundedAmount: refund,
        });
        if (buyerId && refund > 0) {
            tx.update(db.collection("users").doc(buyerId), {
                walletBalance: admin.firestore.FieldValue.increment(refund),
            });
        }
        return { refund };
    });

    return { success: true, refunded: result.refund };
});


/**
 * Trigger: a new order is created (website, iOS/Android app or Vision Pro app).
 * Action: gives it the next invoice number, INV-000001, INV-000002, ... from one counter in Firestore,
 * so every platform shows the same number. The order number (#0CFX1F, the end of the order id) is separate.
 */
exports.assignInvoiceNumber = onDocumentCreated("orders/{orderId}", async (event) => {
    const snap = event.data;
    if (!snap || snap.data().invoiceNumber) return null;

    const db = admin.firestore();
    const counterRef = db.collection("counters").doc("invoices");
    await db.runTransaction(async (tx) => {
        const order = await tx.get(snap.ref);
        if (order.exists && order.data().invoiceNumber) return; // already numbered
        const counter = await tx.get(counterRef);
        const next = ((counter.exists && counter.data().last) || 0) + 1;
        tx.set(counterRef, { last: next });
        tx.update(snap.ref, {
            invoiceNumber: `INV-${String(next).padStart(6, "0")}`,
            invoiceNumberSeq: next,
        });
    });
    return null;
});

/**
 * Trigger: whenever a new order document is created in Firestore.
 * Action: sends immediate push notification to the seller and the buyer,
 * ensuring sellers know instantly when an order arrives (Android & iOS).
 */
exports.onOrderCreated = onDocumentCreated("orders/{orderId}", async (event) => {
    const snap = event.data;
    if (!snap) return null;
    const order = snap.data();
    const orderId = event.params.orderId;
    const db = admin.firestore();

    const sellerId = order.authorId || order.freelancerId || order.sellerId;
    const buyerId = order.clientUid || order.userId || order.buyerId;
    const orderNo = `#${orderId.slice(-6).toUpperCase()}`;
    const priceStr = money(order.price);
    const gigTitle = order.gigTitle || "your gig";

    // 1. Notify Seller
    if (sellerId) {
        const title = `New Order Received! 🚀 · ${orderNo}`;
        const body = `${order.userName || "A client"} placed an order for "${gigTitle}"${priceStr ? " · " + priceStr : ""}. Tap to review details.`;
        await saveNotification(db, sellerId, {
            title: "New order received",
            message: body,
            type: "order",
            orderId,
            orderNumber: orderNo,
            route: `/order-chat/${orderId}`,
        });
        await sendToUser(db, sellerId, {
            title,
            subtitle: gigTitle,
            body,
            route: `/order-chat/${orderId}`,
            data: { orderId },
        });
    }

    // 2. Notify the admins: offline payments wait for them, so every new order is their to-do
    try {
        await notifyAdmins(db, {
            title: `New order ${orderNo}${priceStr ? " · " + priceStr : ""}`,
            body: order.status === "pending_payment"
                ? `${order.userName || "A buyer"} ordered "${gigTitle}". Verify the payment to start it.`
                : `${order.userName || "A buyer"} ordered "${gigTitle}" (paid from wallet).`,
            type: "admin_order",
            link: order.status === "pending_payment" ? "/admin/orders?filter=pending_payment" : "/admin/orders",
            data: { orderId },
            skipUid: buyerId,
        });
    } catch (e) {
        console.error("Admin order notification failed:", e);
    }

    // 3. Notify Buyer
    if (buyerId) {
        const title = `Order Placed Successfully · ${orderNo}`;
        const body = order.status === "pending_payment"
            ? `Your order for "${gigTitle}" is placed. We'll confirm your payment shortly.`
            : `Your order for "${gigTitle}" has been placed securely.`;
        await saveNotification(db, buyerId, {
            title: "Order placed",
            message: body,
            type: "order",
            orderId,
            orderNumber: orderNo,
            route: `/order-chat/${orderId}`,
        });
        await sendToUser(db, buyerId, {
            title,
            subtitle: gigTitle,
            body,
            route: `/order-chat/${orderId}`,
            data: { orderId },
        });
    }

    return null;
});

/**
 * Trigger: whenever a gig/service document is updated.
 * Action: sends immediate push notification when admin approves or rejects a gig.
 */
async function notifyAdminsGigPending(db, gig, gigId) {
    const seller = gig.sellerName || gig.authorName || "A seller";
    await notifyAdmins(db, {
        title: "New gig to review",
        body: `${seller} submitted "${gig.title || "a service"}" for approval.`,
        type: "admin_gig",
        link: "/admin/services",
        data: { gigId },
        skipUid: gig.authorId,
    });
}

exports.onServiceCreated = onDocumentCreated("services/{gigId}", async (event) => {
    const gig = event.data ? event.data.data() : null;
    if (!gig || gig.status !== "pending") return null;
    try {
        await notifyAdminsGigPending(admin.firestore(), gig, event.params.gigId);
    } catch (e) {
        console.error("Admin gig notification failed:", e);
    }
    return null;
});

exports.onServiceUpdated = onDocumentUpdated("services/{gigId}", async (event) => {
    const before = event.data && event.data.before ? event.data.before.data() : null;
    const after = event.data && event.data.after ? event.data.after.data() : null;
    if (!before || !after) return null;

    const gigId = event.params.gigId;
    const db = admin.firestore();
    const authorId = after.authorId;
    if (!authorId) return null;

    // Sent (back) for approval, e.g. edited after a rejection
    if (before.status !== "pending" && after.status === "pending") {
        try {
            await notifyAdminsGigPending(db, after, gigId);
        } catch (e) {
            console.error("Admin gig notification failed:", e);
        }
        return null;
    }

    // Gig Approved (status changed to active)
    if (before.status !== "active" && after.status === "active") {
        const title = "Gig Approved! 🎉";
        const body = `Your gig "${after.title || 'Service'}" has been approved by admin and is now live!`;
        await saveNotification(db, authorId, {
            title,
            message: body,
            type: "gig_approved",
            link: `/gig/${after.slug || gigId}`,
            route: `/gig/${gigId}`,
        });
        await sendToUser(db, authorId, {
            title,
            subtitle: after.title,
            body,
            route: `/gig/${gigId}`,
            data: { gigId },
        });
    }
    // Gig Rejected
    else if (before.status !== "rejected" && after.status === "rejected") {
        const title = "Gig Needs Attention";
        const body = `Your gig "${after.title || 'Service'}" was not approved. Please review details and resubmit.`;
        await saveNotification(db, authorId, {
            title,
            message: body,
            type: "gig_rejected",
            route: "/my-orders",
        });
        await sendToUser(db, authorId, {
            title,
            subtitle: after.title,
            body,
            route: "/my-orders",
            data: { gigId },
        });
    }

    return null;
});


/**
 * Scheduled: every hour, gentle reminders so orders keep moving.
 *  - seller: delivery is due within 24 hours (or is late)
 *  - buyer:  paid but no requirements sent for 2 days
 *  - buyer:  delivery has been waiting for approval for 2 days
 * Each reminder is sent once (flag saved on the order) and shows the order + invoice number.
 */
exports.orderReminders = onSchedule("every 60 minutes", async () => {
    const db = admin.firestore();
    const now = Date.now();
    const HOUR = 3600 * 1000;
    const ms = (t) => (t && t.toMillis ? t.toMillis() : null);

    const remind = async (orderDoc, flag, uid, { title, body, type }) => {
        const o = orderDoc.data();
        const orderNo = `#${orderDoc.id.slice(-6).toUpperCase()}`;
        const invoiceNo = o.invoiceNumber || "";
        // Order chat (if any) so a tap opens the conversation
        const chatSnap = await db.collection("conversations").where("orderId", "==", orderDoc.id).limit(1).get();
        const chatId = chatSnap.empty ? null : chatSnap.docs[0].id;
        const route = chatId ? `/chat/${chatId}` : "/my-orders";

        await saveNotification(db, uid, {
            title, message: body, type, chatId, orderId: orderDoc.id,
            orderNumber: orderNo, invoiceNumber: invoiceNo,
        });
        await sendToUser(db, uid, {
            title: `${title} · ${orderNo}`,
            body: invoiceNo ? `${body}\n${invoiceNo}` : body,
            route, data: { orderId: orderDoc.id },
        });
        await orderDoc.ref.update({ [`reminders.${flag}`]: true });
    };

    // Seller: delivery due soon / late
    for (const status of ["in_progress", "processing", "revision"]) {
        const snap = await db.collection("orders").where("status", "==", status).get();
        for (const d of snap.docs) {
            const o = d.data();
            if ((o.reminders || {}).dueSoon || !o.authorId) continue;
            const started = ms(o.startedAt);
            if (!started) continue;
            const due = started + (o.deliveryDays || 3) * 24 * HOUR;
            if (due - now < 24 * HOUR) {
                const late = due < now;
                await remind(d, "dueSoon", o.authorId, {
                    type: "delivery",
                    title: late ? "Delivery is overdue" : "Delivery due within 24 hours",
                    body: `${o.gigTitle || "Your order"} · deliver on time to keep your rating high`,
                });
            }
        }
    }

    // Buyer: paid, but no requirements yet
    const reqSnap = await db.collection("orders").where("status", "==", "requirements").get();
    for (const d of reqSnap.docs) {
        const o = d.data();
        const buyer = o.clientUid || o.userId;
        if ((o.reminders || {}).requirements || !buyer) continue;
        const created = ms(o.createdAt);
        if (created && now - created > 48 * HOUR) {
            await remind(d, "requirements", buyer, {
                type: "requirements",
                title: "Send your requirements",
                body: `${o.gigTitle || "Your order"} · the seller is waiting to start`,
            });
        }
    }

    // Buyer: delivery waiting for approval
    const delSnap = await db.collection("orders").where("status", "==", "delivered").get();
    for (const d of delSnap.docs) {
        const o = d.data();
        const buyer = o.clientUid || o.userId;
        if ((o.reminders || {}).approval || !buyer) continue;
        const delivered = ms(o.deliveredAt);
        if (delivered && now - delivered > 48 * HOUR) {
            await remind(d, "approval", buyer, {
                type: "delivery",
                title: "Your delivery is waiting",
                body: `${o.gigTitle || "Your order"} · approve it or ask for a revision`,
            });
        }
    }
});
