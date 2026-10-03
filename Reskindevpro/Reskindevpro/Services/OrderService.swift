import Foundation
import FirebaseFirestore
import FirebaseFunctions

/// Order writes, ported 1:1 from the website so web, Flutter and Vision Pro stay in sync:
/// checkout → app/order/[gigId]/[pkg]/page.js, order actions → app/profile/orders/page.js + app/inbox/page.js,
/// chat cards → lib/sendSystemMessage.js
@MainActor
enum OrderService {
    private static var db: Firestore { Firestore.firestore() }

    // MARK: - Checkout

    struct CheckoutForm {
        var phone = ""
        var company = ""
        var address = ""
        var requirements = ""
        var payWithWallet = false
    }

    struct Coupon: Equatable {
        let id: String
        let code: String
        let discount: Double
    }

    struct Pricing {
        let base: Double
        let discount: Double
        let feePercent: Double

        var discounted: Double { max(0, base - discount) }
        var feeAmount: Double { discounted * feePercent / 100 }
        var total: Double { discounted + feeAmount }
    }

    /// settings/global.serviceFee (percent), 5 when missing — same default as the website
    static func serviceFeePercent() async -> Double {
        let snap = try? await db.collection("settings").document("global").getDocument()
        return FS.double(snap?.data()?["serviceFee"]) ?? 5
    }

    static func coupon(code: String) async throws -> Coupon {
        let clean = code.trimmingCharacters(in: .whitespaces).uppercased()
        let snap = try await db.collection("coupons").whereField("code", isEqualTo: clean).getDocuments()
        guard let doc = snap.documents.first else { throw OrderError.invalidCoupon }
        let d = doc.data()
        if let limit = FS.int(d["usageLimit"]), limit > 0, (FS.int(d["usageCount"]) ?? 0) >= limit {
            throw OrderError.couponLimit
        }
        return Coupon(id: doc.documentID, code: clean, discount: FS.double(d["discount"]) ?? 0)
    }

    /// Creates the order + its WorkStream chat. Returns (orderID, chatID).
    static func placeOrder(gig: GigModel, package: GigPackage, form: CheckoutForm, pricing: Pricing,
                           coupon: Coupon?, session: SessionStore) async throws -> (orderID: String, chatID: String?) {
        guard let uid = session.uid else { throw SessionError.signInRequired }
        guard !form.phone.trimmingCharacters(in: .whitespaces).isEmpty else { throw OrderError.phoneRequired }

        let total = pricing.total
        let paidByWallet = form.payWithWallet && session.walletBalance >= total
        let status = paidByWallet ? "requirements" : "pending_payment"

        let order: [String: Any] = [
            "gigId": gig.id,
            "gigTitle": gig.title.isEmpty ? "Untitled" : gig.title,
            "packageId": package.name.lowercased(),
            "packageName": package.name.isEmpty ? "Custom" : package.name,
            "price": total,
            "basePrice": pricing.base,
            "discountAmount": pricing.discount,
            "serviceFee": pricing.feeAmount,
            "status": status,
            "deliveryDays": package.deliveryDays,
            "userId": uid,
            "userName": session.displayName.isEmpty ? "Client" : session.displayName,
            "userEmail": session.email,
            "phone": form.phone.trimmingCharacters(in: .whitespaces),
            "company": form.company.trimmingCharacters(in: .whitespaces),
            "address": form.address.trimmingCharacters(in: .whitespaces),
            "requirements": form.requirements.trimmingCharacters(in: .whitespacesAndNewlines),
            "authorId": gig.authorId.isEmpty ? "admin" : gig.authorId,
            "freelancerId": gig.authorId.isEmpty ? "admin" : gig.authorId,
            "freelancerName": gig.sellerName.isEmpty ? "Seller" : gig.sellerName,
            "createdAt": Date(),
        ]

        let orderRef = db.collection("orders").document()
        if paidByWallet {
            // Wallet payment: order + balance deduction in one batch
            let batch = db.batch()
            batch.setData(order, forDocument: orderRef)
            batch.updateData(["walletBalance": session.walletBalance - total],
                             forDocument: db.collection("users").document(uid))
            try await batch.commit()
        } else {
            try await orderRef.setData(order)
        }

        let chatID = await sendSystemMessage(
            buyerId: uid, buyerName: session.displayName,
            sellerId: gig.authorId, sellerName: gig.sellerName,
            orderId: orderRef.documentID, gigTitle: gig.title,
            actionType: paidByWallet ? "payment_verified" : "order_placed",
            text: "Order Placed: \(String(format: "$%.2f", total)) for \(gig.title)",
            price: total
        )

        if let coupon {
            try? await db.collection("coupons").document(coupon.id).updateData(["usageCount": FieldValue.increment(Int64(1))])
        }
        return (orderRef.documentID, chatID)
    }

    /// Buyer accepts a seller's custom offer through checkout (website app/checkout/custom/page.js)
    static func placeCustomOrder(offer message: ChatMessage, in chat: Conversation, form: CheckoutForm,
                                 pricing: Pricing, session: SessionStore) async throws -> (orderID: String, chatID: String?) {
        guard let uid = session.uid else { throw SessionError.signInRequired }
        guard !form.phone.trimmingCharacters(in: .whitespaces).isEmpty else { throw OrderError.phoneRequired }
        let chatRef = db.collection("conversations").document(chat.id)
        let messageRef = chatRef.collection("messages").document(message.id)
        if (try await messageRef.getDocument().data()?["offerStatus"] as? String) == "accepted" {
            throw OrderError.offerAlreadyAccepted
        }

        let sellerId = message.senderId
        let sellerName = chat.names[sellerId] ?? "Seller"
        let total = pricing.total
        let paidByWallet = form.payWithWallet && session.walletBalance >= total
        let status = paidByWallet ? "requirements" : "pending_payment"

        let order: [String: Any] = [
            "gigId": "custom",
            "gigTitle": "Custom Offer",
            "packageId": "custom",
            "packageName": "Custom Offer",
            "price": total,
            "basePrice": pricing.base,
            "discountAmount": 0,
            "serviceFee": pricing.feeAmount,
            "status": status,
            "deliveryDays": message.offerDays > 0 ? message.offerDays : 3,
            "userId": uid,
            "userName": session.displayName.isEmpty ? "Client" : session.displayName,
            "userEmail": session.email,
            "phone": form.phone.trimmingCharacters(in: .whitespaces),
            "company": form.company.trimmingCharacters(in: .whitespaces),
            "address": form.address.trimmingCharacters(in: .whitespaces),
            "requirements": form.requirements.trimmingCharacters(in: .whitespacesAndNewlines),
            "freelancerId": sellerId,
            "authorId": sellerId,
            "freelancerName": sellerName,
            "createdAt": Date(),
        ]

        let orderRef = db.collection("orders").document()
        if paidByWallet {
            let batch = db.batch()
            batch.setData(order, forDocument: orderRef)
            batch.updateData(["walletBalance": session.walletBalance - total], forDocument: db.collection("users").document(uid))
            try await batch.commit()
        } else {
            try await orderRef.setData(order)
        }
        try await messageRef.updateData(["offerStatus": "accepted"])

        let newChatID = await sendSystemMessage(
            buyerId: uid, buyerName: session.displayName,
            sellerId: sellerId, sellerName: sellerName,
            orderId: orderRef.documentID, gigTitle: "Custom Offer",
            actionType: paidByWallet ? "payment_verified" : "order_placed",
            text: paidByWallet
                ? "Payment verified via Wallet for \(String(format: "$%.2f", total))"
                : "Order Placed: \(String(format: "$%.2f", total)) for Custom Offer"
        )
        return (orderRef.documentID, newChatID)
    }

    // MARK: - Order actions (WorkStream chat in app/inbox/page.js)

    /// Buyer: requirements → processing, delivery countdown starts
    static func submitRequirements(_ order: OrderModel, text: String, session: SessionStore) async throws {
        try await db.collection("orders").document(order.id).updateData([
            "status": "processing",
            "requirements": text,
            "requirementsText": text,
            "requirementsProvided": true,
            // Delivery countdown starts now
            "startedAt": FieldValue.serverTimestamp(),
            "requirementsSubmittedAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
        ])
        await notify(order, session: session, actionType: "requirements_submitted",
                     text: text.isEmpty ? "The buyer has provided all necessary details. Order is now IN PROGRESS." : text,
                     lastMessage: "Requirements Submitted",
                     extra: ["buyerName": session.displayName.isEmpty ? "Buyer" : session.displayName])
    }

    /// Seller: deliver work
    static func deliver(_ order: OrderModel, message: String, link: String, session: SessionStore) async throws {
        try await db.collection("orders").document(order.id).updateData([
            "status": "delivered",
            "deliveryMessage": message,
            "deliveryLink": link,
            "deliveredAt": FieldValue.serverTimestamp(),
        ])
        await notify(order, session: session, actionType: "order_delivered", text: "I have delivered your order.",
                     lastMessage: "I have delivered your order!",
                     extra: ["deliveryMessage": message, "deliveryLink": link])
    }

    /// Buyer: ask for changes after delivery
    static func requestRevision(_ order: OrderModel, note: String, session: SessionStore) async throws {
        try await db.collection("orders").document(order.id).updateData([
            "status": "revision",
            "revisionNote": note,
            "updatedAt": FieldValue.serverTimestamp(),
        ])
        await notify(order, session: session, actionType: "revision_requested", text: "Revision requested: \(note)",
                     lastMessage: "Revision Requested")
    }

    /// Resolution Center → cancel (either side)
    static func requestCancel(_ order: OrderModel, reason: String, session: SessionStore) async throws {
        let bySeller = order.isSeller(session.uid)
        try await db.collection("orders").document(order.id).updateData([
            "status": bySeller ? "cancel_requested_by_freelancer" : "cancel_requested_by_buyer",
            "cancelReason": reason,
            // Lets the refund function skip orders that were never paid
            "statusBeforeCancel": order.status,
            "updatedAt": FieldValue.serverTimestamp(),
        ])
        await notify(order, session: session, actionType: "cancel_requested", text: "Order Cancellation Requested",
                     lastMessage: "Order cancellation requested.",
                     extra: ["cancelReason": reason, "requestedBy": session.uid ?? ""])
    }

    /// Resolution Center → escalate to admin
    static func escalate(_ order: OrderModel, reason: String, session: SessionStore) async throws {
        try await db.collection("orders").document(order.id).updateData([
            "status": "disputed",
            "escalatedToAdmin": true,
            "updatedAt": FieldValue.serverTimestamp(),
        ])
        await notify(order, session: session, actionType: "escalated_to_admin", text: "Escalated to Admin: \(reason)",
                     lastMessage: "Order Escalated to Admin", extra: ["requestedBy": session.uid ?? ""])
    }

    /// The other side answers a cancel request.
    /// Accepting goes through the `processMutualCancellation` Cloud Function, which cancels and refunds the
    /// buyer's wallet with the Admin SDK (client rules can't write another user's balance). If that function
    /// isn't deployed yet, the order is only marked cancelled and the refund is left to the Reskindev team.
    static func respondToCancel(_ order: OrderModel, accept: Bool, session: SessionStore, messageID: String? = nil, chatID: String? = nil) async throws {
        var text = accept ? "Cancellation Accepted." : "Cancellation Declined."
        if accept {
            do {
                let result = try await Functions.functions()
                    .httpsCallable("processMutualCancellation")
                    .call(["orderId": order.id])
                let refunded = FS.double((result.data as? [String: Any])?["refunded"]) ?? 0
                text = refunded > 0 ? "Cancellation Accepted. \(refunded.usd) refunded to buyer." : "Cancellation Accepted."
            } catch let error as NSError where error.domain == FunctionsErrorDomain
                        && [FunctionsErrorCode.notFound.rawValue, FunctionsErrorCode.unimplemented.rawValue].contains(error.code) {
                // Function not deployed: same status change the website makes, no refund
                try await db.collection("orders").document(order.id).updateData([
                    "status": "cancelled",
                    "cancelledAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp(),
                ])
            }
        } else {
            try await db.collection("orders").document(order.id).updateData([
                "status": "processing",
                "updatedAt": FieldValue.serverTimestamp(),
            ])
        }
        await notify(order, session: session,
                     actionType: accept ? "cancel_accepted" : "cancel_declined",
                     text: text,
                     lastMessage: accept ? "Order Cancelled" : "Cancellation Declined")
        await resolve(messageID: messageID, chatID: chatID)
    }

    /// Seller: ask for more days
    static func requestExtension(_ order: OrderModel, days: Int, reason: String, session: SessionStore) async throws {
        try await db.collection("orders").document(order.id).updateData([
            "extensionRequest": [
                "days": days,
                "reason": reason,
                "requestedAt": FieldValue.serverTimestamp(),
                "status": "pending",
            ],
            "updatedAt": FieldValue.serverTimestamp(),
        ])
        await notify(order, session: session, actionType: "extension_requested",
                     text: "Requested \(days) extra day(s): \(reason)",
                     lastMessage: "Time Extension Requested: +\(days) day(s)",
                     extra: ["extensionDays": days, "requestedBy": session.uid ?? ""])
    }

    /// Buyer: accept / decline the extra days
    static func respondToExtension(_ order: OrderModel, days: Int, accept: Bool, session: SessionStore,
                                   messageID: String? = nil, chatID: String? = nil) async throws {
        let ref = db.collection("orders").document(order.id)
        var update: [String: Any] = ["extensionRequest": NSNull(), "updatedAt": FieldValue.serverTimestamp()]
        if accept {
            let current = FS.int(try await ref.getDocument().data()?["deliveryDays"]) ?? order.deliveryDays
            update["deliveryDays"] = current + days
        }
        try await ref.updateData(update)
        await notify(order, session: session,
                     actionType: accept ? "extension_accepted" : "extension_declined",
                     text: accept ? "Time extension of \(days) day(s) was accepted." : "Time extension request was declined.")
        await resolve(messageID: messageID, chatID: chatID)
    }

    /// Reviews are blind, like the website: the buyer's review stays hidden until the seller reviews back.
    struct ReviewInput {
        var communication = 5
        var service = 5
        var recommend = true
        var comment = ""
        /// Average of communication + service, 1 decimal (website calculatedRating)
        var rating: Double { (Double(communication + service) / 2 * 10).rounded() / 10 }
    }

    private static func reviewData(_ input: ReviewInput, session: SessionStore, fallbackName: String) -> [String: Any] {
        let name = session.displayName.isEmpty ? fallbackName : session.displayName
        return [
            "userId": session.uid ?? "",
            "userName": name,
            "userImage": session.photoUrl.isEmpty
                ? "https://ui-avatars.com/api/?name=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fallbackName)"
                : session.photoUrl,
            "rating": input.rating,
            "communication": input.communication,
            "service": input.service,
            "recommend": input.recommend,
            "comment": input.comment,
            "createdAt": FieldValue.serverTimestamp(),
        ]
    }

    /// Buyer: accept delivery + (hidden) review → completed
    static func acceptDelivery(_ order: OrderModel, review: ReviewInput, session: SessionStore) async throws {
        guard session.uid != nil else { throw SessionError.signInRequired }
        try await db.collection("orders").document(order.id).updateData([
            "status": "completed",
            "hasReview": true,
            "isReviewPublic": false,
            "completedAt": FieldValue.serverTimestamp(),
            "buyerReview": reviewData(review, session: session, fallbackName: "Client"),
        ])
        await notify(order, session: session, actionType: "order_completed",
                     text: "Buyer has accepted the delivery and left a review! Seller needs to leave a review to unlock it.",
                     lastMessage: "Order Accepted & Reviewed",
                     extra: ["rating": 0, "comment": "Hidden review", "isReviewPublic": false])
    }

    /// Seller: review the buyer → both reviews become public
    static func submitSellerReview(_ order: OrderModel, review: ReviewInput, session: SessionStore) async throws {
        guard let uid = session.uid else { throw SessionError.signInRequired }
        let ref = db.collection("orders").document(order.id)
        let current = try await ref.getDocument().data() ?? [:]
        let sellerName = session.displayName.isEmpty ? "Seller" : session.displayName
        let sellerReview = reviewData(review, session: session, fallbackName: "Seller")

        try await ref.updateData(["sellerReview": sellerReview, "isReviewPublic": true])

        // Seller's review → buyer profile
        if !order.buyerId.isEmpty {
            var forBuyer = sellerReview
            forBuyer["orderId"] = order.id
            forBuyer["freelancerId"] = uid
            forBuyer["freelancerName"] = sellerName
            forBuyer["buyerId"] = order.buyerId
            try? await db.collection("users").document(order.buyerId).collection("reviews").addDocument(data: forBuyer)
        }

        // The hidden buyer review → gig + seller profile
        if let buyerReview = current["buyerReview"] as? [String: Any] {
            await publishBuyerReview(buyerReview, order: order, sellerID: uid, sellerName: sellerName)
            await notify(order, session: session, actionType: "text",
                         text: "Both parties have left a review! The reviews are now public on your profiles.")
            await notify(order, session: session, actionType: "order_completed", text: "Order Completed (Reviews Unlocked)",
                         lastMessage: "Reviews Unlocked",
                         extra: [
                            "rating": FS.double(buyerReview["rating"]) ?? 5,
                            "comment": buyerReview["comment"] as? String ?? "Order completed.",
                            "sellerRating": review.rating,
                            "sellerComment": review.comment,
                            "isReviewPublic": true,
                         ])
        }
    }

    // MARK: - Automatic rules the website runs when a WorkStream chat is open

    /// Delivered for 3 days → completed. Buyer review hidden for 14 days without a seller review → published.
    static func applyAutomaticRules(to orders: [OrderModel], session: SessionStore) async {
        let now = Date()
        for order in orders {
            if order.isDelivered, let delivered = order.deliveredAt, now.timeIntervalSince(delivered) > 3 * 86_400 {
                try? await db.collection("orders").document(order.id).updateData([
                    "status": "completed",
                    "completedAt": FieldValue.serverTimestamp(),
                    "autoCompleted": true,
                ])
                await notify(order, session: session, actionType: "order_completed",
                             text: "Order automatically completed after 3 days of no response.")
            }
            if order.isCompleted, order.buyerReview != nil, !order.isReviewPublic, order.sellerReview == nil,
               let completed = order.completedAt, now.timeIntervalSince(completed) > 14 * 86_400 {
                let ref = db.collection("orders").document(order.id)
                try? await ref.updateData(["isReviewPublic": true, "autoPublishedReview": true])
                if let buyerReview = try? await ref.getDocument().data()?["buyerReview"] as? [String: Any] {
                    await publishBuyerReview(buyerReview, order: order, sellerID: order.sellerId, sellerName: "Seller")
                }
            }
        }
    }

    private static func publishBuyerReview(_ buyerReview: [String: Any], order: OrderModel, sellerID: String, sellerName: String) async {
        let rating = FS.double(buyerReview["rating"]) ?? 5
        await publishGigReview(gigId: order.gigId, review: buyerReview, rating: rating, orderID: order.id)
        guard !sellerID.isEmpty else { return }
        try? await db.collection("users").document(sellerID).collection("reviews").addDocument(data: [
            "freelancerId": sellerID,
            "freelancerName": sellerName,
            "orderId": order.id,
            "rating": rating,
            "comment": buyerReview["comment"] as? String ?? "Order completed.",
            "createdAt": buyerReview["createdAt"] ?? FieldValue.serverTimestamp(),
            "buyerName": FS.string(buyerReview["userName"]) ?? "Client",
            "buyerImage": FS.string(buyerReview["userImage"]) ?? "",
        ])
    }

    /// services/{gigId}/reviews + running average on the gig
    private static func publishGigReview(gigId: String, review: [String: Any], rating: Double, orderID: String) async {
        guard !gigId.isEmpty, gigId != "custom" else { return }
        let gigRef = db.collection("services").document(gigId)
        guard let gig = try? await gigRef.getDocument().data() else { return }
        let count = FS.int(gig["reviewCount"]) ?? 0
        let average = FS.double(gig["averageRating"]) ?? FS.double(gig["rating"]) ?? 5
        let newCount = count + 1
        let newAverage = ((average * Double(count) + rating) / Double(newCount) * 10).rounded() / 10

        var published = review
        published["orderId"] = orderID
        try? await gigRef.collection("reviews").addDocument(data: published)
        try? await gigRef.updateData(["reviewCount": newCount, "averageRating": newAverage, "rating": newAverage])
    }

    /// Marks an in-chat request card (cancel / extension) as answered
    private static func resolve(messageID: String?, chatID: String?) async {
        guard let messageID, let chatID else { return }
        try? await db.collection("conversations").document(chatID).collection("messages").document(messageID)
            .updateData(["actionResolved": true])
    }

    // MARK: - Chat cards (lib/sendSystemMessage.js)

    private static func notify(_ order: OrderModel, session: SessionStore, actionType: String, text: String,
                               lastMessage: String? = nil, extra: [String: Any] = [:]) async {
        await sendSystemMessage(
            buyerId: order.buyerId, buyerName: order.buyerName,
            sellerId: order.sellerId, sellerName: order.sellerName,
            orderId: order.id, gigTitle: order.gigTitle,
            actionType: actionType, text: text, price: order.price,
            lastMessage: lastMessage, extra: extra
        )
    }

    /// Posts a system card in the order's WorkStream chat (creating the chat if needed). Returns the chat id.
    @discardableResult
    static func sendSystemMessage(buyerId: String, buyerName: String, sellerId: String, sellerName: String,
                                  orderId: String?, gigTitle: String, actionType: String, text: String,
                                  price: Double = 0, lastMessage: String? = nil,
                                  extra: [String: Any] = [:]) async -> String? {
        guard !buyerId.isEmpty, !sellerId.isEmpty else { return nil }
        do {
            let snap = try await db.collection("conversations").whereField("participants", arrayContains: buyerId).getDocuments()
            var chatID: String?
            if let orderId {
                // 1. The order's own chat
                chatID = snap.documents.first { FS.string($0.data()["orderId"]) == orderId }?.documentID
            } else {
                // 2. General chat between the two (no orderId)
                chatID = snap.documents.first { doc in
                    let d = doc.data()
                    return (d["participants"] as? [String] ?? []).contains(sellerId) && FS.string(d["orderId"]) == nil
                }?.documentID
            }

            if let id = chatID {
                try await db.collection("conversations").document(id).updateData([
                    "lastMessage": lastMessage ?? text,
                    "updatedAt": FieldValue.serverTimestamp(),
                ])
            } else {
                // 3. Create it
                var chat: [String: Any] = [
                    "participants": [buyerId, sellerId],
                    "participantDetails": [
                        buyerId: ["name": buyerName.isEmpty ? "Buyer" : buyerName],
                        sellerId: ["name": sellerName.isEmpty ? "Seller" : sellerName],
                    ],
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp(),
                    "lastMessage": lastMessage ?? text,
                ]
                if let orderId {
                    chat["orderId"] = orderId
                    if !gigTitle.isEmpty { chat["gigTitle"] = gigTitle }
                }
                chatID = try await db.collection("conversations").addDocument(data: chat).documentID
            }
            guard let chatID else { return nil }

            var message: [String: Any] = [
                "type": "system_notification",
                "actionType": actionType,
                "text": text,
                "orderId": orderId ?? NSNull(),
                "gigTitle": gigTitle,
                "price": price,
                "deliveryMessage": "",
                "deliveryLink": "",
                "senderId": "system",
                "createdAt": Date(),
                "read": false,
            ]
            message.merge(extra) { _, new in new }
            try await db.collection("conversations").document(chatID).collection("messages").addDocument(data: message)
            return chatID
        } catch {
            print("🔥 Failed to send system message:", error)
            return nil
        }
    }
}

enum OrderError: LocalizedError {
    case invalidCoupon, couponLimit, phoneRequired, offerAlreadyAccepted

    var errorDescription: String? {
        switch self {
        case .invalidCoupon: "Invalid coupon code"
        case .couponLimit: "Coupon limit reached"
        case .phoneRequired: "Phone number is required."
        case .offerAlreadyAccepted: "This offer has already been accepted."
        }
    }
}
