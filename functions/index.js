const { onDocumentWritten } = require("firebase-functions/v2/firestore");
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
 * Trigger: Whenever a new message is added to a conversation.
 * Action: Sends a push notification to the other participant.
 */
exports.sendChatPushNotification = onDocumentCreated("conversations/{chatId}/messages/{messageId}", async (event) => {
    const snap = event.data;
    if (!snap) return;

    const messageData = snap.data();
    const senderId = messageData.senderId;
    const chatId = event.params.chatId;

    // Do not send notifications for system messages unless they are important (like order updates)
    if (senderId === 'system' && !messageData.actionType) {
        return;
    }

    const db = admin.firestore();
    
    // Fetch conversation details to find the other participant
    const chatDoc = await db.collection("conversations").doc(chatId).get();
    if (!chatDoc.exists) return;

    const chatData = chatDoc.data();
    const participants = chatData.participants || [];
    
    let recipientId = null;
    
    if (senderId === 'system') {
        // If it's a system message, try to deduce who to send it to.
        // For example, if actionType is 'order_placed', send to seller.
        // Actually, send system messages to BOTH participants if it's an order update!
        // But for simplicity, if participant length is 2, we can just fetch both, 
        // or let's say system messages are meant to notify everyone.
        // For standard chat, we notify the NON-SENDER.
    } else {
        recipientId = participants.find(id => id !== senderId);
    }

    // Determine target users to notify
    const usersToNotify = recipientId ? [recipientId] : participants.filter(id => id !== senderId && id !== 'system');
    
    if (usersToNotify.length === 0) return;

    // Fetch sender info for notification title
    let title = "New Message";
    let body = messageData.text || "You received a new message.";
    
    if (senderId !== 'system') {
        title = messageData.senderName || "New Message";
    } else {
        title = "Reskindev Notification";
    }

    // Fallbacks for specific system messages
    if (messageData.actionType === 'order_completed') {
        title = "Order Completed!";
    } else if (messageData.actionType === 'order_delivered') {
        title = "Delivery Received!";
    } else if (messageData.actionType === 'order_placed') {
        title = "New Order Placed!";
    }

    for (const uid of usersToNotify) {
        const userDoc = await db.collection("users").doc(uid).get();
        if (userDoc.exists) {
            const userData = userDoc.data();
            // fcmToken = the iOS app's device; fcmTokens = extra devices (Vision Pro)
            const tokens = [...new Set([userData.fcmToken, ...(userData.fcmTokens || [])].filter(Boolean))];

            for (const token of tokens) {
                const payload = {
                    notification: {
                        title: title,
                        body: body,
                    },
                    data: {
                        route: `/chat/${chatId}`,
                        click_action: "FLUTTER_NOTIFICATION_CLICK"
                    },
                    token: token,
                };

                try {
                    await admin.messaging().send(payload);
                    console.log(`Push notification sent successfully to user ${uid}`);
                } catch (error) {
                    console.error(`Error sending push notification to user ${uid}:`, error);
                    // Drop extra-device tokens that no longer exist (app deleted / signed out)
                    if (error.code === "messaging/registration-token-not-registered" && token !== userData.fcmToken) {
                        await userDoc.ref.update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(token) });
                    }
                }
            }
        }
    }
    
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
