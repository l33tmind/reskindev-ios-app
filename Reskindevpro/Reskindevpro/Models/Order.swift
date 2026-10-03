import Foundation

/// buyerReview / sellerReview stored on the order document
struct OrderReview: Hashable {
    let rating: Double
    let comment: String

    init?(_ value: Any?) {
        guard let d = value as? [String: Any] else { return nil }
        self.rating = FS.double(d["rating"]) ?? 0
        self.comment = d["comment"] as? String ?? ""
    }

    var stars: Int { Int(rating.rounded()) }
}

/// orders/{id}.extensionRequest (seller asks for more days)
struct ExtensionRequest: Hashable {
    let days: Int
    let reason: String

    init?(_ value: Any?) {
        guard let d = value as? [String: Any], (d["status"] as? String ?? "pending") == "pending" else { return nil }
        self.days = FS.int(d["days"]) ?? 1
        self.reason = d["reason"] as? String ?? ""
    }
}

// MARK: - Order (same fields the website writes in app/order/[gigId]/[pkg]/page.js)

struct OrderModel: Identifiable, Hashable {
    let id: String
    let gigId: String
    let gigTitle: String
    let packageName: String
    let price: Double
    let basePrice: Double
    let serviceFee: Double
    let discountAmount: Double
    let quantity: Int
    let deliveryDays: Int
    /// userId (website) or clientUid (Flutter)
    let buyerId: String
    let buyerName: String
    let buyerImage: String
    /// freelancerId or authorId
    let sellerId: String
    let authorId: String
    let sellerName: String
    let status: String
    let requirements: String
    let deliveryMessage: String
    let deliveryLink: String
    let revisionNote: String
    let cancelReason: String
    let credentials: String
    let buyerReview: OrderReview?
    let sellerReview: OrderReview?
    let isReviewPublic: Bool
    let extensionRequest: ExtensionRequest?
    let createdAt: Date
    /// When the buyer's requirements came in: the delivery countdown starts here
    let startedAt: Date?
    let deliveredAt: Date?
    let completedAt: Date?

    init(id: String, data: [String: Any]) {
        self.id = id
        self.gigId = data["gigId"] as? String ?? ""
        self.gigTitle = FS.string(data["gigTitle"]) ?? "Order"
        self.packageName = FS.string(data["packageName"]) ?? "Basic"
        self.price = FS.double(data["price"]) ?? 0
        self.basePrice = FS.double(data["basePrice"]) ?? FS.double(data["price"]) ?? 0
        self.serviceFee = FS.double(data["serviceFee"]) ?? 0
        self.discountAmount = FS.double(data["discountAmount"]) ?? 0
        self.quantity = FS.int(data["quantity"]) ?? 1
        self.deliveryDays = FS.int(data["deliveryDays"]) ?? 3
        self.buyerId = FS.string(data["userId"]) ?? FS.string(data["clientUid"]) ?? ""
        // New (userName) and legacy (clientName) field names, same as Flutter
        self.buyerName = FS.string(data["userName"]) ?? FS.string(data["clientName"]) ?? ""
        self.buyerImage = FS.string(data["userImage"]) ?? ""
        self.sellerId = FS.string(data["freelancerId"]) ?? FS.string(data["authorId"]) ?? ""
        self.authorId = FS.string(data["authorId"]) ?? ""
        self.sellerName = FS.string(data["freelancerName"]) ?? FS.string(data["authorName"]) ?? ""
        self.status = FS.string(data["status"]) ?? "requirements"
        // The chat writes `requirements`, the orders page `requirementsText`
        self.requirements = FS.string(data["requirements"]) ?? FS.string(data["requirementsText"]) ?? ""
        self.deliveryMessage = data["deliveryMessage"] as? String ?? ""
        self.deliveryLink = data["deliveryLink"] as? String ?? ""
        self.revisionNote = data["revisionNote"] as? String ?? ""
        self.cancelReason = data["cancelReason"] as? String ?? ""
        self.credentials = data["credentials"] as? String ?? ""
        self.buyerReview = OrderReview(data["buyerReview"])
        self.sellerReview = OrderReview(data["sellerReview"])
        self.isReviewPublic = data["isReviewPublic"] as? Bool ?? false
        self.extensionRequest = ExtensionRequest(data["extensionRequest"])
        self.createdAt = FS.date(data["createdAt"]) ?? .now
        self.startedAt = FS.date(data["requirementsSubmittedAt"]) ?? FS.date(data["startedAt"])
        self.deliveredAt = FS.date(data["deliveredAt"])
        self.completedAt = FS.date(data["completedAt"])
    }

    var isPendingPayment: Bool { status == "pending_payment" }
    var needsRequirements: Bool { status == "requirements" || status == "pending" }
    var isInProgress: Bool { ["processing", "in_progress", "revision"].contains(status) }
    /// Delivery countdown runs while the seller is working (website WorkspaceTimelineDetails)
    var isTimerRunning: Bool { isInProgress || status == "disputed" }
    /// Requirements submitted + deliveryDays (website My Orders LiveTimer); older orders fall back to createdAt
    var dueDate: Date { (startedAt ?? createdAt).addingTimeInterval(Double(deliveryDays) * 86_400) }
    var isDelivered: Bool { status == "delivered" }
    var isCompleted: Bool { status == "completed" }
    var isCancelRequested: Bool { status.hasPrefix("cancel_requested") }

    /// Can still be cancelled (same statuses the website allows)
    var isCancellable: Bool { needsRequirements || isInProgress || isPendingPayment }

    func isBuyer(_ uid: String?) -> Bool { uid != nil && uid == buyerId }
    func isSeller(_ uid: String?) -> Bool { uid != nil && (uid == sellerId || uid == authorId) }

    /// Index in `OrderTimeline.steps` (Payment → Requirements → Processing → Delivered → Completed),
    /// or nil for statuses that don't sit on the timeline (cancelled, disputed, ...).
    var timelineStep: Int? {
        switch status {
        case "pending_payment": return 0
        case "requirements", "pending": return 1
        case "processing", "in_progress", "revision", "disputed": return 2
        case "delivered": return 3
        case "completed": return 4
        default: return nil
        }
    }

    var statusLabel: String {
        switch status {
        case "pending_payment": return "Pending Payment"
        case "requirements", "pending": return "Waiting for Requirements"
        case "processing", "in_progress": return "In Progress"
        case "revision": return "Revision Requested"
        case "delivered": return "Delivered"
        case "completed": return "Completed"
        case "cancelled": return "Cancelled"
        case "cancel_requested_by_buyer": return "Cancel Requested (Buyer)"
        case "cancel_requested_by_freelancer": return "Cancel Requested (Seller)"
        case "disputed": return "Disputed"
        default: return status.capitalized
        }
    }
}

// MARK: - "What's next" for the orders list (one clear step per order)

extension OrderModel {
    /// The single action this person should take now, if any
    func nextAction(for uid: String?) -> OrderAction? {
        if isBuyer(uid) {
            if needsRequirements { return .requirements }
            if isDelivered { return .acceptDelivery }
            if isCompleted && buyerReview == nil { return .acceptDelivery }
        }
        if isSeller(uid) {
            if isInProgress { return .deliver }
            if isCompleted && buyerReview != nil && sellerReview == nil { return .reviewBuyer }
        }
        return nil
    }

    /// Friendlier button text than the form title
    func nextActionTitle(for uid: String?) -> String? {
        switch nextAction(for: uid) {
        case .requirements: "Tell the seller what you need"
        case .acceptDelivery: isCompleted ? "Leave a review" : "Review delivery & accept"
        case .deliver: status == "revision" ? "Deliver the revision" : "Deliver your work"
        case .reviewBuyer: "Rate the buyer"
        default: nil
        }
    }

    /// Shown when it's the other side's turn
    func waitingText(for uid: String?) -> String? {
        let buyer = isBuyer(uid)
        switch status {
        case "pending_payment": return buyer ? "Reskindev will contact you to confirm payment" : "Waiting for the buyer's payment"
        case "requirements", "pending": return buyer ? nil : "Waiting for the buyer's requirements"
        case "processing", "in_progress", "revision": return buyer ? "The seller is working on it" : nil
        case "delivered": return buyer ? nil : "Waiting for the buyer to accept"
        case "cancel_requested_by_buyer": return buyer ? "Waiting for the seller to respond" : "The buyer asked to cancel — open the order to respond"
        case "cancel_requested_by_freelancer": return buyer ? "The seller asked to cancel — open the order to respond" : "Waiting for the buyer to respond"
        case "disputed": return "Reskindev is reviewing this order"
        default: return nil
        }
    }
}
