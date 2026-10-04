import SwiftUI
import Observation
import UIKit
import FirebaseFirestore
import FirebaseStorage

// MARK: - Seller tools: My Gigs, gig editor, earnings + withdrawals
// Website: app/profile/gigs, app/profile/gigs/edit/[id], app/profile/earnings

/// Editable copy of a services/{id} document
struct GigDraft {
    struct Package: Identifiable {
        let id = UUID()
        var name: String
        var price: Double
        var description: String
        var deliveryDays: Int
        var featureChecks: [Bool]
    }

    var id: String?
    var title = ""
    var descriptionText = ""
    /// The HTML the website editor wrote; kept as-is when the text isn't changed
    var originalHTML = ""
    var category = "Service"
    var keywords: [String] = []
    var youtubeUrl = ""
    var videoConsent = false
    var imageUrl = ""
    /// Optional .usdz shown with "View in Your Room"
    var model3dUrl = ""
    var masterFeatures: [String] = []
    var status = "pending"
    var packages: [Package] = [
        .init(name: "Basic", price: 0, description: "", deliveryDays: 3, featureChecks: []),
        .init(name: "Standard", price: 0, description: "", deliveryDays: 5, featureChecks: []),
        .init(name: "Premium", price: 0, description: "", deliveryDays: 7, featureChecks: []),
    ]
    /// Uneditable fields the website keeps "behind the scenes"
    var extra: [String: Any] = [:]

    var isNew: Bool { id == nil }

    init() {}

    init(id: String, data: [String: Any]) {
        self.id = id
        title = data["title"] as? String ?? ""
        originalHTML = data["description"] as? String ?? ""
        descriptionText = GigModel.plainText(fromHTML: originalHTML)
        category = FS.string(data["category"]) ?? "Service"
        keywords = data["keywords"] as? [String] ?? []
        youtubeUrl = (data["youtubeUrls"] as? [String])?.first ?? data["youtubeUrl"] as? String ?? ""
        videoConsent = data["videoConsent"] as? Bool ?? false
        imageUrl = data["imageUrl"] as? String ?? ""
        model3dUrl = data["model3dUrl"] as? String ?? ""
        masterFeatures = data["masterFeatures"] as? [String] ?? []
        status = FS.string(data["status"]) ?? "pending"
        let pkgs = (data["packages"] as? [[String: Any]] ?? []).map { p in
            Package(name: p["name"] as? String ?? "Basic",
                    price: FS.double(p["price"]) ?? 0,
                    description: p["description"] as? String ?? "",
                    deliveryDays: FS.int(p["deliveryDays"]) ?? 3,
                    featureChecks: p["featureChecks"] as? [Bool] ?? [])
        }
        if !pkgs.isEmpty { packages = pkgs }
        extra = [
            "galleryUnlockPrice": data["galleryUnlockPrice"] ?? 0,
            "deliveryCost": data["deliveryCost"] ?? 0,
        ]
    }

    /// 1 to 3 packages, like the iOS app
    mutating func addPackage() {
        guard packages.count < 3 else { return }
        let names = ["Basic", "Standard", "Premium"]
        let name = names.first { n in !packages.contains { $0.name == n } } ?? "Package \(packages.count + 1)"
        packages.append(.init(name: name, price: 0, description: "", deliveryDays: 3,
                              featureChecks: Array(repeating: false, count: masterFeatures.count)))
    }

    mutating func removePackage(id: UUID) {
        guard packages.count > 1 else { return }
        packages.removeAll { $0.id == id }
    }

    mutating func addFeature(_ name: String) {
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        masterFeatures.append(clean)
        for i in packages.indices { packages[i].featureChecks = padded(packages[i].featureChecks) + [false] }
    }

    mutating func removeFeature(at index: Int) {
        masterFeatures.remove(at: index)
        for i in packages.indices where index < packages[i].featureChecks.count {
            packages[i].featureChecks.remove(at: index)
        }
    }

    func isChecked(package: Int, feature: Int) -> Bool {
        feature < packages[package].featureChecks.count && packages[package].featureChecks[feature]
    }

    mutating func toggle(package: Int, feature: Int) {
        var checks = padded(packages[package].featureChecks)
        checks[feature].toggle()
        packages[package].featureChecks = checks
    }

    private func padded(_ checks: [Bool]) -> [Bool] {
        checks.count >= masterFeatures.count ? Array(checks.prefix(masterFeatures.count))
            : checks + Array(repeating: false, count: masterFeatures.count - checks.count)
    }

    /// Description as HTML for the website (paragraph per line) unless untouched
    var descriptionHTML: String {
        if descriptionText == GigModel.plainText(fromHTML: originalHTML) && !originalHTML.isEmpty { return originalHTML }
        return descriptionText
            .components(separatedBy: "\n")
            .map { line in
                let escaped = line.replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
                return escaped.isEmpty ? "<p><br></p>" : "<p>\(escaped)</p>"
            }
            .joined()
    }
}

/// One gig row in My Gigs (includes pending / paused ones the marketplace hides)
struct MyGig: Identifiable, Hashable {
    let id: String
    let title: String
    let imageUrl: String
    let status: String
    let price: Double
    let category: String

    var statusLabel: String {
        switch status {
        case "active", "published": "Live"
        case "pending": "Pending Approval"
        case "rejected": "Rejected"
        case "paused": "Paused"
        default: status.capitalized
        }
    }
    var statusColor: Color {
        switch status {
        case "active", "published": .brandGreen
        case "pending": .starYellow
        case "rejected": .red
        default: .secondary
        }
    }
}

struct EarningsSummary {
    var totalEarnings: Double = 0
    var pendingClearance: Double = 0
    var available: Double = 0
    var withdrawn: Double = 0
    var completedOrders = 0
    var platformFee: Double = 10
    var pending: [(title: String, amount: Double, clearsAt: Date)] = []
    var withdrawals: [(amount: Double, status: String, date: Date?)] = []
    /// Seller's share per month, last 6 months, oldest first (3D chart)
    var monthly: [(month: Date, amount: Double)] = []
}

@Observable
final class SellerStore {
    private(set) var gigs: [MyGig] = []
    private(set) var gigsLoading = false
    private(set) var earnings = EarningsSummary()
    private(set) var earningsLoading = false

    @ObservationIgnored private var gigsListener: ListenerRegistration?
    @ObservationIgnored private var uid: String?
    private var db: Firestore { Firestore.firestore() }

    func bind(uid: String?) {
        guard uid != self.uid else { return }
        self.uid = uid
        gigsListener?.remove(); gigsListener = nil
        gigs = []
        earnings = EarningsSummary()
        guard let uid else { return }
        gigsLoading = true
        gigsListener = db.collection("services").whereField("authorId", isEqualTo: uid)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                self.gigsLoading = false
                self.gigs = (snap?.documents ?? []).map { doc in
                    let d = doc.data()
                    let images = d["images"] as? [String] ?? []
                    return MyGig(
                        id: doc.documentID,
                        title: d["title"] as? String ?? "Untitled",
                        imageUrl: FS.string(d["imageUrl"]) ?? images.first ?? "",
                        status: FS.string(d["status"]) ?? "pending",
                        price: FS.double(((d["packages"] as? [[String: Any]])?.first)?["price"]) ?? 0,
                        category: d["category"] as? String ?? ""
                    )
                }
                .sorted { $0.title < $1.title }
            }
    }

    // MARK: Gig editor

    func loadDraft(id: String) async throws -> GigDraft {
        let snap = try await db.collection("services").document(id).getDocument()
        return GigDraft(id: id, data: snap.data() ?? [:])
    }

    /// Same payload as the website editor; every save goes back to "pending" for admin approval
    func save(_ draft: GigDraft, newImage: UIImage?, newModel: URL? = nil, session: SessionStore) async throws {
        guard let uid = session.uid else { throw SessionError.signInRequired }
        guard !draft.title.trimmed.isEmpty else { throw SellerError.titleRequired }
        let youtube = draft.youtubeUrl.trimmed
        let hasMedia = newImage != nil || !draft.imageUrl.isEmpty || !youtube.isEmpty
        guard hasMedia else { throw SellerError.mediaRequired }
        if !draft.videoConsent { throw SellerError.videoConsent }

        var imageUrl = draft.imageUrl
        if let newImage { imageUrl = try await upload(newImage, uid: uid) }
        // Video only: its YouTube thumbnail is the cover (iOS app)
        if imageUrl.isEmpty, let id = GigModel.youtubeID(from: youtube) {
            imageUrl = "https://img.youtube.com/vi/\(id)/maxresdefault.jpg"
        }
        var model3dUrl = draft.model3dUrl
        if let newModel { model3dUrl = try await uploadModel(newModel, uid: uid) }

        var payload: [String: Any] = [
            "title": draft.title.trimmed,
            "description": draft.descriptionHTML,
            "category": draft.category,
            "keywords": draft.keywords,
            "youtubeUrl": youtube,
            "youtubeUrls": youtube.isEmpty ? [] : [youtube],
            "videoConsent": draft.videoConsent,
            "videoConsentTimestamp": (!youtube.isEmpty && draft.videoConsent) ? Date() : NSNull(),
            "imageUrl": imageUrl,
            "images": imageUrl.isEmpty ? [] : [imageUrl],
            "model3dUrl": model3dUrl,
            "masterFeatures": draft.masterFeatures,
            "packages": draft.packages.map { p in
                [
                    "name": p.name,
                    "price": p.price,
                    "description": p.description,
                    "deliveryDays": p.deliveryDays,
                    "featureChecks": Array(p.featureChecks.prefix(draft.masterFeatures.count))
                        + Array(repeating: false, count: max(0, draft.masterFeatures.count - p.featureChecks.count)),
                ] as [String: Any]
            },
            "status": "pending",
            "isDeleted": false,
            "isActive": false,
            "updatedAt": Date(),
        ]
        payload.merge(draft.extra) { current, _ in current }

        if let id = draft.id {
            try await db.collection("services").document(id).setData(payload, merge: true)
        } else {
            payload["authorId"] = uid
            payload["authorName"] = session.displayName.isEmpty ? "Seller" : session.displayName
            payload["authorImage"] = session.photoUrl.isEmpty
                ? "https://ui-avatars.com/api/?name=\(session.displayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                : session.photoUrl
            payload["createdAt"] = Date()
            // Website uses the timestamp as the document id
            let newID = String(Int(Date().timeIntervalSince1970 * 1000))
            try await db.collection("services").document(newID).setData(payload)
        }
    }

    func delete(gigID: String) async throws {
        try await db.collection("services").document(gigID).delete()
    }

    /// gigs/{uid}/{timestamp}_{random}.jpg, at most 5 MB (compressed only when bigger)
    private func upload(_ image: UIImage, uid: String) async throws -> String {
        var quality: CGFloat = 0.85
        var data = image.jpegData(compressionQuality: quality)
        var working = image
        while let d = data, d.count > 5_000_000 {
            if quality > 0.4 {
                quality -= 0.15
            } else {
                let size = CGSize(width: working.size.width * 0.75, height: working.size.height * 0.75)
                working = UIGraphicsImageRenderer(size: size).image { _ in working.draw(in: CGRect(origin: .zero, size: size)) }
            }
            data = working.jpegData(compressionQuality: quality)
        }
        guard let data else { throw SellerError.imageUnreadable }

        let name = "\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(6).lowercased()).jpg"
        let ref = Storage.storage().reference().child("gigs/\(uid)/\(name)")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        return try await ref.downloadURL().absoluteString
    }

    /// gig_models/{uid}/{timestamp}.usdz (under 25 MB, the Storage rules limit)
    private func uploadModel(_ file: URL, uid: String) async throws -> String {
        let scoped = file.startAccessingSecurityScopedResource()
        defer { if scoped { file.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: file)
        guard data.count < 25 * 1024 * 1024 else { throw SellerError.modelTooLarge }
        let ref = Storage.storage().reference().child("gig_models/\(uid)/\(Int(Date().timeIntervalSince1970 * 1000)).usdz")
        let metadata = StorageMetadata()
        metadata.contentType = "model/vnd.usdz+zip"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        return try await ref.downloadURL().absoluteString
    }

    // MARK: Earnings (same math as the website: platform fee, 15-day clearance)

    func loadEarnings(session: SessionStore) async {
        guard let uid = session.uid else { return }
        earningsLoading = true
        defer { earningsLoading = false }

        let fee = FS.double(try? await db.collection("settings").document("global").getDocument().data()?["platformFee"]) ?? 10
        let orders = (try? await db.collection("orders").whereField("authorId", isEqualTo: uid).getDocuments())?.documents ?? []
        let withdrawals = (try? await db.collection("withdrawals").whereField("freelancerId", isEqualTo: uid).getDocuments())?.documents ?? []

        var summary = EarningsSummary(platformFee: fee)
        let clearance: TimeInterval = 15 * 86_400
        var available: Double = 0
        let calendar = Calendar.current
        let thisMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        let months = (0..<6).reversed().compactMap { calendar.date(byAdding: .month, value: -$0, to: thisMonth) }
        var byMonth = Dictionary(uniqueKeysWithValues: months.map { ($0, 0.0) })
        for doc in orders {
            let d = doc.data()
            guard d["status"] as? String == "completed" else { continue }
            summary.completedOrders += 1
            let price = FS.double(d["price"]) ?? 0
            let share = price - price * fee / 100
            summary.totalEarnings += share
            if let date = FS.date(d["completedAt"]) ?? FS.date(d["createdAt"]),
               let month = calendar.dateInterval(of: .month, for: date)?.start, byMonth[month] != nil {
                byMonth[month, default: 0] += share
            }
            if let completed = FS.date(d["completedAt"]), Date().timeIntervalSince(completed) < clearance {
                summary.pendingClearance += share
                summary.pending.append((FS.string(d["gigTitle"]) ?? "Order", share, completed.addingTimeInterval(clearance)))
            } else {
                available += share
            }
        }
        for doc in withdrawals {
            let d = doc.data()
            summary.withdrawn += FS.double(d["fromEarnings"]) ?? FS.double(d["amount"]) ?? 0
            summary.withdrawals.append((FS.double(d["amount"]) ?? 0, FS.string(d["status"]) ?? "pending", FS.date(d["createdAt"])))
        }
        summary.available = available - summary.withdrawn + session.walletBalance
        summary.monthly = months.map { ($0, byMonth[$0] ?? 0) }
        summary.pending.sort { $0.clearsAt < $1.clearsAt }
        summary.withdrawals.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        earnings = summary
    }

    /// Payoneer withdrawal request (min $20, $3 charge), wallet balance used first
    func requestWithdrawal(amount: Double, email: String, session: SessionStore) async throws {
        guard let uid = session.uid else { throw SessionError.signInRequired }
        guard amount >= 20 else { throw SellerError.minimumWithdrawal }
        guard amount <= earnings.available else { throw SellerError.insufficientFunds }

        let fromWallet = min(amount, max(0, session.walletBalance))
        if fromWallet > 0 {
            try await db.collection("users").document(uid).updateData(["walletBalance": FieldValue.increment(-fromWallet)])
        }
        try await db.collection("withdrawals").addDocument(data: [
            "freelancerId": uid,
            "freelancerName": session.displayName,
            "email": email.trimmed,
            "amount": amount,
            "charge": 3,
            "netAmount": amount - 3,
            "status": "pending",
            "fromWallet": fromWallet,
            "fromEarnings": amount - fromWallet,
            "createdAt": FieldValue.serverTimestamp(),
        ])
        await loadEarnings(session: session)
    }
}

enum SellerError: LocalizedError {
    case titleRequired, videoConsent, mediaRequired, imageUnreadable, modelTooLarge, minimumWithdrawal, insufficientFunds

    var errorDescription: String? {
        switch self {
        case .titleRequired: "Title is required!"
        case .videoConsent: "You must accept the Mandatory UGC & Copyright Declaration."
        case .mediaRequired: "Add a picture or a YouTube video."
        case .imageUnreadable: "Couldn't read that image."
        case .modelTooLarge: "The 3D model must be smaller than 25 MB."
        case .minimumWithdrawal: "Minimum withdrawal is $20."
        case .insufficientFunds: "Insufficient available funds."
        }
    }
}
