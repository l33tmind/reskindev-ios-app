import Foundation

/// A public review in services/{gigId}/reviews (written when both sides of an order have reviewed)
struct GigReview: Identifiable, Hashable {
    let id: String
    let userName: String
    let userImage: String
    let rating: Int
    let comment: String
    let createdAt: Date?
    let sellerReply: String?

    init(id: String, data: [String: Any]) {
        self.id = id
        self.userName = FS.string(data["userName"]) ?? FS.string(data["buyerName"]) ?? "Client"
        self.userImage = FS.string(data["userImage"]) ?? FS.string(data["buyerImage"]) ?? ""
        self.rating = FS.int(data["rating"]) ?? 0
        self.comment = data["comment"] as? String ?? ""
        self.createdAt = FS.date(data["createdAt"])
        self.sellerReply = FS.string(FS.map(data["sellerReply"])["comment"])
            ?? FS.string(FS.map(data["sellerResponse"])["comment"])
    }
}
