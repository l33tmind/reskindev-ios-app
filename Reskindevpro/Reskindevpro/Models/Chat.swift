import Foundation

// MARK: - Conversation (conversations/{id}, same fields as the website inbox)

struct Conversation: Identifiable, Hashable {
    let id: String
    let participants: [String]
    /// participantDetails.{uid}.name
    let names: [String: String]
    let lastMessage: String
    let updatedAt: Date?
    let unread: [String: Int]
    let typing: [String: Bool]
    /// Set for order "WorkStream" chats
    let orderId: String?
    let gigTitle: String?
    let clientId: String?
    let freelancerId: String?

    init(id: String, data: [String: Any]) {
        self.id = id
        self.clientId = FS.string(data["clientId"])
        self.freelancerId = FS.string(data["freelancerId"])
        self.participants = data["participants"] as? [String] ?? []
        self.names = FS.map(data["participantDetails"]).compactMapValues { FS.string(FS.map($0)["name"]) }
        self.lastMessage = data["lastMessage"] as? String ?? ""
        self.updatedAt = FS.date(data["updatedAt"])
        self.unread = FS.map(data["unreadCount"]).compactMapValues { FS.int($0) }
        self.typing = FS.map(data["typing"]).compactMapValues { $0 as? Bool }
        self.orderId = FS.string(data["orderId"])
        self.gigTitle = FS.string(data["gigTitle"])
    }

    func otherID(me: String) -> String? {
        participants.first { $0 != me } ?? names.keys.first { $0 != me }
    }

    func title(me: String) -> String {
        otherID(me: me).flatMap { names[$0] } ?? "Conversation"
    }

    func unreadCount(for uid: String) -> Int { unread[uid] ?? 0 }

    func isOtherTyping(me: String) -> Bool {
        guard let other = otherID(me: me) else { return false }
        return typing[other] ?? false
    }
}

// MARK: - Message (conversations/{id}/messages/{id})

struct ChatMessage: Identifiable, Hashable {
    enum Kind: Hashable { case text, system, offer }

    let id: String
    let kind: Kind
    let text: String
    let senderId: String
    let senderName: String
    let createdAt: Date?

    // System cards
    let actionType: String
    let orderId: String?
    let gigTitle: String
    let price: Double
    let deliveryMessage: String
    let deliveryLink: String
    let rating: Int?
    let comment: String
    let cancelReason: String
    let requestedBy: String
    let extensionDays: Int
    /// Cancel / extension card already answered
    let actionResolved: Bool
    let isReviewPublic: Bool
    let sellerRating: Double?
    let sellerComment: String

    // Custom offers
    let offerPrice: Double
    let offerDays: Int
    let offerDescription: String
    let offerStatus: String

    // Replies / gig reference
    let replyToText: String?
    let replyToSender: String?
    let gigImage: String?

    init(id: String, data: [String: Any]) {
        self.id = id
        let type = data["type"] as? String ?? "text"
        let sender = data["senderId"] as? String ?? ""
        self.kind = type == "offer" ? .offer
            : (type == "system_notification" || sender == "system") ? .system
            : .text
        self.text = data["text"] as? String ?? ""
        self.senderId = sender
        self.senderName = data["senderName"] as? String ?? ""
        self.createdAt = FS.date(data["createdAt"])
        self.actionType = data["actionType"] as? String ?? ""
        self.orderId = FS.string(data["orderId"])
        self.gigTitle = data["gigTitle"] as? String ?? ""
        self.price = FS.double(data["price"]) ?? 0
        self.deliveryMessage = data["deliveryMessage"] as? String ?? ""
        self.deliveryLink = data["deliveryLink"] as? String ?? ""
        self.rating = FS.double(data["rating"]).map { Int($0.rounded()) }
        self.comment = data["comment"] as? String ?? ""
        self.cancelReason = data["cancelReason"] as? String ?? ""
        self.requestedBy = data["requestedBy"] as? String ?? ""
        self.extensionDays = FS.int(data["extensionDays"]) ?? 0
        self.actionResolved = data["actionResolved"] as? Bool ?? false
        self.isReviewPublic = data["isReviewPublic"] as? Bool ?? false
        self.sellerRating = FS.double(data["sellerRating"])
        self.sellerComment = data["sellerComment"] as? String ?? ""
        self.offerPrice = FS.double(data["offerPrice"]) ?? 0
        self.offerDays = FS.int(data["offerDays"]) ?? 0
        self.offerDescription = data["offerDescription"] as? String ?? ""
        self.offerStatus = data["offerStatus"] as? String ?? "pending"
        self.replyToText = FS.string(data["replyToText"])
        self.replyToSender = FS.string(data["replyToSender"])
        self.gigImage = FS.string(data["gigImage"])
    }

    /// Title + SF Symbol for system cards, by actionType
    var systemStyle: (title: String, icon: String) {
        switch actionType {
        case "order_placed": ("Order Placed", "cart.fill")
        case "payment_verified": ("Payment Verified", "checkmark.seal.fill")
        case "requirements_submitted": ("Requirements Submitted", "doc.text.fill")
        case "order_delivered": ("Order Delivered", "shippingbox.fill")
        case "order_completed": ("Order Completed", "star.fill")
        case "revision_requested": ("Revision Requested", "arrow.uturn.backward.circle.fill")
        case "cancel_requested": ("Cancellation Requested", "xmark.octagon.fill")
        case "cancel_accepted": ("Cancellation Accepted", "xmark.circle.fill")
        case "cancel_declined": ("Cancellation Declined", "arrow.clockwise.circle.fill")
        case "escalated_to_admin": ("Escalated to Admin", "exclamationmark.shield.fill")
        case "extension_requested": ("Time Extension Requested", "clock.badge.questionmark")
        case "extension_accepted": ("Time Extension Accepted", "clock.badge.checkmark")
        case "extension_declined": ("Time Extension Declined", "clock.badge.xmark")
        case "dispute_opened": ("Dispute Opened", "exclamationmark.shield.fill")
        case "system_update": ("Order Update", "arrow.triangle.2.circlepath")
        default: ("Update", "info.circle.fill")
        }
    }
}
