import SwiftUI
import Observation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Signed-in user and their orders (same users/{uid} fields as the website's AuthContext)

@Observable
final class SessionStore {
    enum Mode: String { case buyer, seller }

    private(set) var uid: String?
    private(set) var email = ""
    private(set) var displayName = ""
    private(set) var photoUrl = ""
    private(set) var role: String?
    private(set) var username = ""
    private(set) var phone = ""
    private(set) var country = ""
    private(set) var bio = ""
    private(set) var walletBalance: Double = 0
    private(set) var savedGigIDs: [String] = []
    private(set) var blockedUsers: [String] = []
    private(set) var memberSince: Date?
    private(set) var orders: [OrderModel] = []
    private(set) var ordersLoading = false
    /// Admin → Users: status "blocked" / verified badge
    private(set) var accountStatus = "active"
    private(set) var isVerified = false
    /// Admin order updates (notifications) + broadcasts (users/{uid}/notifications)
    private(set) var notifications: [AppNotification] = []
    var unreadNotifications: Int { notifications.filter { !$0.read }.count }
    var isBlockedByAdmin: Bool { accountStatus == "blocked" }

    /// Buyer sees orders they placed; seller sees orders placed on their gigs
    var mode: Mode = .buyer {
        didSet { if oldValue != mode { listenToOrders() } }
    }

    var isSignedIn: Bool { uid != nil }
    var canSell: Bool { role == "freelancer" || role == "admin" }
    var nameOrFallback: String { displayName.isEmpty ? "User" : displayName }

    func isSaved(_ gigID: String) -> Bool { savedGigIDs.contains(gigID) }
    func order(id: String) -> OrderModel? { orders.first { $0.id == id } }

    @ObservationIgnored private var authHandle: AuthStateDidChangeListenerHandle?
    @ObservationIgnored private var userListener: ListenerRegistration?
    @ObservationIgnored private var ordersListener: ListenerRegistration?
    @ObservationIgnored private var notificationListeners: [ListenerRegistration] = []
    @ObservationIgnored private var notificationsByKey: [String: AppNotification] = [:]
    // Resolved lazily so SwiftUI previews (no FirebaseApp.configure) don't crash
    private var db: Firestore { Firestore.firestore() }

    func start() {
        guard authHandle == nil else { return }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.userChanged(user)
        }
    }

    // MARK: Auth actions

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email.trimmingCharacters(in: .whitespaces), password: password)
    }

    /// Apple / Google: same Firebase account as the iOS app. The users/{uid} doc is created by the
    /// listener below if this is the person's first sign-in anywhere.
    func signIn(with credential: AuthCredential, fallbackName: String? = nil) async throws {
        let result = try await Auth.auth().signIn(with: credential)
        if let fallbackName, (result.user.displayName ?? "").isEmpty {
            let change = result.user.createProfileChangeRequest()
            change.displayName = fallbackName
            try? await change.commitChanges()
            displayName = fallbackName
            try? await db.collection("users").document(result.user.uid)
                .setData(["displayName": fallbackName, "name": fallbackName], merge: true)
        }
    }

    /// Same as the website's signupWithEmail: Auth user + users/{uid} document
    func signUp(name: String, email: String, password: String, role: String) async throws {
        let cleanEmail = email.trimmingCharacters(in: .whitespaces)
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        let result = try await Auth.auth().createUser(withEmail: cleanEmail, password: password)
        let avatar = "https://ui-avatars.com/api/?name=\(cleanName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        let change = result.user.createProfileChangeRequest()
        change.displayName = cleanName
        change.photoURL = URL(string: avatar)
        try await change.commitChanges()

        try await db.collection("users").document(result.user.uid).setData([
            "uid": result.user.uid,
            "email": cleanEmail,
            "displayName": cleanName,
            "photoURL": avatar,
            "role": role,
            "username": Self.makeUsername(from: cleanEmail),
            "createdAt": FieldValue.serverTimestamp(),
            "lastLogin": FieldValue.serverTimestamp(),
        ])
        displayName = cleanName
        photoUrl = avatar
    }

    func signOut() {
        if let uid { db.collection("users").document(uid).setData(["isOnline": false], merge: true) }
        try? Auth.auth().signOut()
    }

    func deleteAccount() async throws {
        try await Auth.auth().currentUser?.delete()
    }

    // MARK: Profile actions

    /// Heart button: users/{uid}.savedGigs arrayUnion / arrayRemove (website SaveButton)
    func toggleSave(_ gigID: String) async throws {
        guard let uid else { throw SessionError.signInRequired }
        let wasSaved = isSaved(gigID)
        // Optimistic update so the heart reacts instantly
        if wasSaved { savedGigIDs.removeAll { $0 == gigID } } else { savedGigIDs.append(gigID) }
        do {
            try await db.collection("users").document(uid).updateData([
                "savedGigs": wasSaved ? FieldValue.arrayRemove([gigID]) : FieldValue.arrayUnion([gigID])
            ])
        } catch {
            if wasSaved { savedGigIDs.append(gigID) } else { savedGigIDs.removeAll { $0 == gigID } }
            throw error
        }
    }

    /// Settings page: username must be unique (same check as the website)
    func updateProfile(displayName: String, username: String, phone: String, country: String, bio: String) async throws {
        guard let uid else { throw SessionError.signInRequired }
        var payload: [String: Any] = [
            "displayName": displayName.trimmingCharacters(in: .whitespaces),
            "phone": phone.trimmingCharacters(in: .whitespaces),
            "country": country.trimmingCharacters(in: .whitespaces),
            "bio": bio,
        ]
        let newUsername = username.trimmingCharacters(in: .whitespaces)
        if !newUsername.isEmpty {
            if newUsername != self.username {
                let taken = try await db.collection("users").whereField("username", isEqualTo: newUsername).getDocuments()
                if taken.documents.contains(where: { $0.documentID != uid }) { throw SessionError.usernameTaken }
            }
            payload["username"] = newUsername
        }
        try await db.collection("users").document(uid).updateData(payload)
        if let user = Auth.auth().currentUser, user.displayName != payload["displayName"] as? String {
            let change = user.createProfileChangeRequest()
            change.displayName = payload["displayName"] as? String
            try? await change.commitChanges()
        }
    }

    // MARK: Listeners

    private func userChanged(_ user: User?) {
        [userListener, ordersListener].forEach { $0?.remove() }
        userListener = nil; ordersListener = nil
        notificationListeners.forEach { $0.remove() }
        notificationListeners = []
        notificationsByKey = [:]
        notifications = []
        accountStatus = "active"
        isVerified = false

        uid = user?.uid
        email = user?.email ?? ""
        displayName = user?.displayName ?? user?.email?.components(separatedBy: "@").first ?? ""
        photoUrl = user?.photoURL?.absoluteString ?? ""
        role = nil
        username = ""; phone = ""; country = ""; bio = ""
        walletBalance = 0
        savedGigIDs = []
        blockedUsers = []
        memberSince = nil
        orders = []
        mode = .buyer

        guard let user else { return }
        let ref = db.collection("users").document(user.uid)

        userListener = ref.addSnapshotListener { [weak self] snap, _ in
            guard let self, let snap else { return }
            guard let d = snap.data() else {
                // No profile yet (e.g. account made elsewhere): create it like the website's fallback
                if !snap.metadata.isFromCache { self.createMissingProfile(for: user) }
                return
            }
            if let name = FS.string(d["displayName"]) ?? FS.string(d["name"]) { self.displayName = name }
            // Website writes photoURL, Flutter wrote photoUrl
            if let photo = FS.string(d["photoURL"]) ?? FS.string(d["photoUrl"]) { self.photoUrl = photo }
            self.role = d["role"] as? String
            self.username = d["username"] as? String ?? ""
            self.phone = d["phone"] as? String ?? ""
            self.country = d["country"] as? String ?? ""
            self.bio = d["bio"] as? String ?? ""
            self.walletBalance = FS.double(d["walletBalance"]) ?? 0
            self.savedGigIDs = d["savedGigs"] as? [String] ?? []
            self.blockedUsers = d["blockedUsers"] as? [String] ?? []
            self.memberSince = FS.date(d["createdAt"])
            self.accountStatus = FS.string(d["status"]) ?? "active"
            self.isVerified = d["verified"] as? Bool ?? false
            if (d["isOnline"] as? Bool) != true {
                ref.setData(["isOnline": true, "lastLogin": FieldValue.serverTimestamp()], merge: true)
            }
        }

        listenToOrders()
        listenToNotifications(uid: user.uid)
    }

    // MARK: Notifications (website Navbar bell)

    private func listenToNotifications(uid: String) {
        let apply: (QuerySnapshot?, Bool) -> Void = { [weak self] snap, broadcast in
            guard let self, let snap else { return }
            let prefix = broadcast ? "b:" : "n:"
            self.notificationsByKey = self.notificationsByKey.filter { !$0.key.hasPrefix(prefix) }
            for doc in snap.documents {
                self.notificationsByKey[prefix + doc.documentID] = AppNotification(doc: doc, isBroadcast: broadcast)
            }
            self.notifications = self.notificationsByKey.values.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        }
        notificationListeners = [
            db.collection("notifications").whereField("userId", isEqualTo: uid)
                .addSnapshotListener { snap, _ in apply(snap, false) },
            db.collection("users").document(uid).collection("notifications")
                .addSnapshotListener { snap, _ in apply(snap, true) },
        ]
    }

    func markRead(_ notification: AppNotification) {
        notification.ref.updateData(["read": true])
    }

    func markAllNotificationsRead() {
        notifications.filter { !$0.read }.forEach(markRead)
    }

    private func createMissingProfile(for user: User) {
        db.collection("users").document(user.uid).setData([
            "uid": user.uid,
            "email": user.email ?? "",
            "displayName": user.displayName ?? "",
            "photoURL": user.photoURL?.absoluteString ?? "",
            "role": "buyer",
            "username": Self.makeUsername(from: user.email ?? ""),
            "createdAt": FieldValue.serverTimestamp(),
            "lastLogin": FieldValue.serverTimestamp(),
        ], merge: true)
    }

    private func listenToOrders() {
        ordersListener?.remove()
        ordersListener = nil
        orders = []
        guard let uid else { return }
        ordersLoading = true

        // Firestore rules only allow reading orders the user belongs to, so the query must filter by uid
        let query: Query = switch mode {
        case .buyer:
            db.collection("orders").whereFilter(.orFilter([
                .whereField("userId", isEqualTo: uid),
                .whereField("clientUid", isEqualTo: uid),
            ]))
        case .seller:
            db.collection("orders").whereField("authorId", isEqualTo: uid)
        }

        ordersListener = query.addSnapshotListener { [weak self] snap, error in
            guard let self else { return }
            self.ordersLoading = false
            if let error { print("🔥 Firestore orders error:", error) }
            self.orders = (snap?.documents ?? [])
                .map { OrderModel(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }
        }
    }

    /// "robius_4821" — same pattern as the website
    private static func makeUsername(from email: String) -> String {
        let base = (email.components(separatedBy: "@").first ?? "user")
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        return "\(base.isEmpty ? "user" : base)_\(Int.random(in: 0..<10000))"
    }
}

enum SessionError: LocalizedError {
    case signInRequired, usernameTaken

    var errorDescription: String? {
        switch self {
        case .signInRequired: "Please sign in first."
        case .usernameTaken: "This username is already taken. Please choose another."
        }
    }
}

/// Admin order updates (notifications/{id}) and broadcasts (users/{uid}/notifications/{id})
struct AppNotification: Identifiable, Hashable {
    let id: String
    let title: String
    let message: String
    let type: String
    let link: String
    let read: Bool
    let createdAt: Date?
    let ref: DocumentReference

    init(doc: QueryDocumentSnapshot, isBroadcast: Bool) {
        let d = doc.data()
        id = (isBroadcast ? "b:" : "n:") + doc.documentID
        title = FS.string(d["title"]) ?? (isBroadcast ? "Announcement" : "Update")
        message = d["message"] as? String ?? ""
        type = d["type"] as? String ?? (isBroadcast ? "broadcast" : "order")
        link = d["link"] as? String ?? ""
        read = d["read"] as? Bool ?? false
        createdAt = FS.date(d["createdAt"])
        ref = doc.reference
    }

    static func == (a: Self, b: Self) -> Bool { a.id == b.id && a.read == b.read }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
