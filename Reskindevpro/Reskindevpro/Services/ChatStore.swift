import SwiftUI
import Observation
import FirebaseFirestore

// MARK: - Inbox: conversations + messages of the open chat (website app/inbox/page.js)

@Observable
final class ChatStore {
    private(set) var conversations: [Conversation] = []
    private(set) var messages: [ChatMessage] = []
    private(set) var conversationsLoading = false
    private(set) var messagesLoading = false

    // WorkStream context for the open chat (website inbox right panel)
    /// Orders between me and the other person, newest first
    private(set) var chatOrders: [OrderModel] = []
    private(set) var otherUser: OtherUser?
    private(set) var buyerQuickReplies = ["Any updates?", "Looks great!", "When can I expect delivery?"]
    private(set) var sellerQuickReplies = ["Hi, I am working on it!", "Do you have any reference?", "Thanks for the order!"]

    struct OtherUser: Equatable {
        let name: String
        let photoUrl: String
        let isOnline: Bool
        let blockedUsers: [String]
    }

    /// Chat open in the Inbox window
    var activeChatID: String? {
        didSet {
            guard oldValue != activeChatID else { return }
            listenToMessages()
            listenToWorkspace()
            markActiveChatRead()
        }
    }

    private(set) var uid: String?
    @ObservationIgnored private var myName = ""
    @ObservationIgnored private var conversationsListener: ListenerRegistration?
    @ObservationIgnored private var messagesListener: ListenerRegistration?
    @ObservationIgnored private var workspaceListeners: [ListenerRegistration] = []
    @ObservationIgnored private var ordersByID: [String: OrderModel] = [:]
    @ObservationIgnored private var typingResetTask: Task<Void, Never>?
    @ObservationIgnored private var isTyping = false
    private var db: Firestore { Firestore.firestore() }

    var activeChat: Conversation? { conversations.first { $0.id == activeChatID } }

    /// Red badge on the dock's Inbox button
    var unreadTotal: Int {
        guard let uid else { return 0 }
        return conversations.reduce(0) { $0 + $1.unreadCount(for: uid) }
    }

    /// Called whenever the signed-in user changes
    func bind(uid: String?, name: String) {
        myName = name
        guard uid != self.uid else { return }
        self.uid = uid
        conversationsListener?.remove(); conversationsListener = nil
        messagesListener?.remove(); messagesListener = nil
        workspaceListeners.forEach { $0.remove() }; workspaceListeners = []
        conversations = []
        messages = []
        activeChatID = nil
        guard let uid else { return }

        conversationsLoading = true
        conversationsListener = db.collection("conversations")
            .whereField("participants", arrayContains: uid)
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }
                self.conversationsLoading = false
                if let error { print("🔥 Firestore conversations error:", error) }
                // Sorted here instead of orderBy so chats without updatedAt still show
                self.conversations = (snap?.documents ?? [])
                    .map { Conversation(id: $0.documentID, data: $0.data(with: .estimate)) }
                    .sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
                if self.activeChat?.unreadCount(for: uid) ?? 0 > 0 { self.markActiveChatRead() }
                // Chat opened before the list loaded (e.g. right after checkout)
                if self.activeChatID != nil, self.workspaceListeners.isEmpty { self.listenToWorkspace() }
            }
    }

    // MARK: WorkStream context

    /// The order shown in the workspace panel: the chat's own order, else the newest one between the two
    var currentOrder: OrderModel? {
        if let id = activeChat?.orderId, let order = chatOrders.first(where: { $0.id == id }) { return order }
        return chatOrders.first
    }

    var amIBuyer: Bool {
        guard let uid else { return false }
        if !chatOrders.isEmpty { return chatOrders.contains { $0.isBuyer(uid) } }
        return activeChat?.clientId == uid
    }

    var amISeller: Bool {
        guard let uid else { return false }
        if !chatOrders.isEmpty { return chatOrders.contains { $0.isSeller(uid) } }
        return activeChat?.freelancerId == uid
    }

    var isBlocked: Bool {
        guard let uid, let other = activeChat?.otherID(me: uid) else { return false }
        return blockedByMe.contains(other) || (otherUser?.blockedUsers.contains(uid) ?? false)
    }

    /// Filled from users/{me}.blockedUsers by the session
    var blockedByMe: [String] = []

    var quickReplies: [String] {
        if amIBuyer && !amISeller { return buyerQuickReplies }
        if amISeller && !amIBuyer { return sellerQuickReplies }
        var seen = Set<String>()
        return Array((buyerQuickReplies + sellerQuickReplies).filter { seen.insert($0).inserted }.prefix(5))
    }

    private func listenToWorkspace() {
        workspaceListeners.forEach { $0.remove() }
        workspaceListeners = []
        ordersByID = [:]
        chatOrders = []
        otherUser = nil
        guard let uid, let chat = activeChat ?? conversations.first(where: { $0.id == activeChatID }) else { return }
        let other = chat.otherID(me: uid) ?? uid
        let orders = db.collection("orders")

        let apply: (QuerySnapshot?) -> Void = { [weak self] snap in
            guard let self else { return }
            snap?.documents.forEach { self.ordersByID[$0.documentID] = OrderModel(id: $0.documentID, data: $0.data()) }
            self.chatOrders = self.ordersByID.values.sorted { $0.createdAt > $1.createdAt }
        }
        // I'm the buyer, they sell — and the other way round (same two queries as the website)
        workspaceListeners.append(orders.whereField("userId", isEqualTo: uid).whereField("authorId", isEqualTo: other)
            .addSnapshotListener { snap, _ in apply(snap) })
        workspaceListeners.append(orders.whereField("userId", isEqualTo: other).whereField("authorId", isEqualTo: uid)
            .addSnapshotListener { snap, _ in apply(snap) })
        if let orderID = chat.orderId {
            workspaceListeners.append(orders.document(orderID).addSnapshotListener { [weak self] snap, _ in
                guard let self, let snap, let data = snap.data() else { return }
                self.ordersByID[snap.documentID] = OrderModel(id: snap.documentID, data: data)
                self.chatOrders = self.ordersByID.values.sorted { $0.createdAt > $1.createdAt }
            })
        }

        workspaceListeners.append(db.collection("users").document(other).addSnapshotListener { [weak self] snap, _ in
            guard let self, let d = snap?.data() else { return }
            self.otherUser = OtherUser(
                name: FS.string(d["displayName"]) ?? FS.string(d["name"]) ?? chat.title(me: uid),
                photoUrl: FS.string(d["photoURL"]) ?? FS.string(d["photoUrl"]) ?? "",
                isOnline: d["isOnline"] as? Bool ?? false,
                blockedUsers: d["blockedUsers"] as? [String] ?? []
            )
        })

        Task { [weak self] in await self?.loadQuickReplies() }
    }

    private func loadQuickReplies() async {
        guard let d = try? await db.collection("settings").document("global").getDocument().data() else { return }
        let fallback = d["chatSuggestions"] as? [String]
        if let buyer = d["buyerChatSuggestions"] as? [String] ?? fallback, !buyer.isEmpty { buyerQuickReplies = buyer }
        if let seller = d["sellerChatSuggestions"] as? [String] ?? fallback, !seller.isEmpty { sellerQuickReplies = seller }
    }

    func toggleBlock() async throws {
        guard let uid, let other = activeChat?.otherID(me: uid) else { return }
        let blocked = blockedByMe.contains(other)
        try await db.collection("users").document(uid).updateData([
            "blockedUsers": blocked ? FieldValue.arrayRemove([other]) : FieldValue.arrayUnion([other])
        ])
    }

    func report(reason: String) async throws {
        guard let uid, let other = activeChat?.otherID(me: uid) else { return }
        try await db.collection("reports").addDocument(data: [
            "reportedBy": uid,
            "reportedUser": other,
            "reason": reason,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "pending",
        ])
    }

    func conversation(forOrder orderID: String) -> Conversation? {
        conversations.first { $0.orderId == orderID }
    }

    // MARK: Messages

    private func listenToMessages() {
        messagesListener?.remove(); messagesListener = nil
        messages = []
        guard let chatID = activeChatID else { return }
        messagesLoading = true
        messagesListener = db.collection("conversations").document(chatID).collection("messages")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snap, error in
                guard let self, self.activeChatID == chatID else { return }
                self.messagesLoading = false
                if let error { print("🔥 Firestore messages error:", error) }
                self.messages = (snap?.documents ?? []).map {
                    ChatMessage(id: $0.documentID, data: $0.data(with: .estimate))
                }
            }
    }

    private func markActiveChatRead() {
        guard let uid, let chatID = activeChatID else { return }
        db.collection("conversations").document(chatID).updateData([
            "unreadCount.\(uid)": 0,
            "lastReadTime.\(uid)": FieldValue.serverTimestamp(),
        ])
    }

    /// Call on every keystroke: typing.{uid} = true, back to false after 2s idle
    func userTyped() {
        guard let uid, let chatID = activeChatID else { return }
        if !isTyping {
            isTyping = true
            db.collection("conversations").document(chatID).updateData(["typing.\(uid)": true])
        }
        typingResetTask?.cancel()
        typingResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            self.isTyping = false
            try? await self.db.collection("conversations").document(chatID).updateData(["typing.\(uid)": false])
        }
    }

    func send(text: String, replyTo: ChatMessage? = nil) async throws {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let uid, let chat = activeChat, !body.isEmpty else { return }
        typingResetTask?.cancel()
        isTyping = false

        var message: [String: Any] = [
            "text": body,
            "senderId": uid,
            "senderName": myName,
            "createdAt": Date(),
            "type": "text",
        ]
        if let replyTo {
            message["replyToId"] = replyTo.id
            message["replyToText"] = replyTo.text.isEmpty ? "Attachment" : replyTo.text
            message["replyToSender"] = replyTo.senderId == uid ? myName : (replyTo.senderName.isEmpty ? "Other" : replyTo.senderName)
        }
        let ref = db.collection("conversations").document(chat.id)
        try await ref.collection("messages").addDocument(data: message)

        var update: [String: Any] = [
            "lastMessage": body,
            "updatedAt": Date(),
            "typing.\(uid)": false,
            "msgCount": FieldValue.increment(Int64(1)),
        ]
        if let other = chat.otherID(me: uid) { update["unreadCount.\(other)"] = FieldValue.increment(Int64(1)) }
        try await ref.updateData(update)
    }

    /// Seller → buyer custom offer (website handleSendOffer)
    func sendOffer(price: Double, days: Int, description: String) async throws {
        guard let uid, let chat = activeChat else { return }
        let ref = db.collection("conversations").document(chat.id)
        try await ref.collection("messages").addDocument(data: [
            "text": "Sent a custom offer",
            "senderId": uid,
            "senderName": myName,
            "createdAt": Date(),
            "type": "offer",
            "offerPrice": price,
            "offerDays": days,
            "offerDescription": description,
            "offerStatus": "pending",
        ])
        var update: [String: Any] = ["lastMessage": "Custom Offer: \(price.usd)", "updatedAt": Date()]
        if let other = chat.otherID(me: uid) { update["unreadCount.\(other)"] = FieldValue.increment(Int64(1)) }
        try await ref.updateData(update)
    }

    // MARK: Contact seller (website ContactSellerButton)

    /// Finds or creates the general (non-order) chat with the gig's seller and posts the gig reference.
    /// Returns the conversation id.
    func contactSeller(gig: GigModel) async throws -> String {
        try await contact(userID: gig.authorId, name: gig.sellerName, gig: gig)
    }

    /// General chat with any user (seller profile "Contact Me"), optionally posting a gig reference
    func contact(userID: String, name: String, gig: GigModel? = nil) async throws -> String {
        guard let uid else { throw SessionError.signInRequired }
        guard userID != uid else { throw ChatError.messageYourself }

        let snap = try await db.collection("conversations").whereField("participants", arrayContains: uid).getDocuments()
        var chatID = snap.documents.first { doc in
            let d = doc.data()
            return (d["participants"] as? [String] ?? []).contains(userID) && FS.string(d["orderId"]) == nil
        }?.documentID

        if chatID == nil {
            let ref = try await db.collection("conversations").addDocument(data: [
                "participants": [uid, userID],
                "freelancerId": userID,
                "clientId": uid,
                "participantDetails": [
                    uid: ["name": myName.isEmpty ? "User" : myName],
                    userID: ["name": name.isEmpty ? "Freelancer" : name],
                ],
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "lastMessage": "",
            ])
            chatID = ref.documentID
        }
        guard let chatID else { throw ChatError.unknown }

        if let gig {
            let ref = db.collection("conversations").document(chatID)
            try await ref.collection("messages").addDocument(data: [
                "text": "Hi! I'm interested in your service:\n\(gig.title)\nhttps://reskindev.com/gig/\(gig.id)",
                "senderId": uid,
                "senderName": myName.isEmpty ? "User" : myName,
                "createdAt": FieldValue.serverTimestamp(),
                "type": "text",
                "gigImage": gig.imageUrl.isEmpty ? NSNull() : gig.imageUrl,
            ])
            try await ref.updateData([
                "lastMessage": "Interested in: \(gig.title)",
                "updatedAt": FieldValue.serverTimestamp(),
                "unreadCount.\(userID)": FieldValue.increment(Int64(1)),
            ])
        }
        return chatID
    }
}

enum ChatError: LocalizedError {
    case messageYourself, unknown

    var errorDescription: String? {
        switch self {
        case .messageYourself: "You cannot message yourself."
        case .unknown: "Something went wrong. Please try again."
        }
    }
}
