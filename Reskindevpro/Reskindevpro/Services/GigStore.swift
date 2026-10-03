import SwiftUI
import Observation
import FirebaseFirestore

// MARK: - Live store for the `services` collection

@Observable
final class GigStore {
    private(set) var gigs: [GigModel] = []
    /// Admin-managed list (admin_settings/categories), or the gigs' own categories when that can't be read (guests)
    var categories: [String] {
        if !adminCategories.isEmpty { return adminCategories }
        var seen = Set<String>()
        return gigs.map(\.category).filter { !$0.isEmpty && seen.insert($0).inserted }
    }
    private var adminCategories: [String] = []
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    var searchText = ""
    var selectedCategory: String? = nil   // nil = All

    /// Admin-managed pages (Privacy Policy, Terms, Refund…) from the `pages` collection
    private(set) var pages: [SitePage] = []

    @ObservationIgnored private var pagesListener: ListenerRegistration?
    @ObservationIgnored private var gigsListener: ListenerRegistration?
    @ObservationIgnored private var categoriesListener: ListenerRegistration?

    /// Gigs after search + category filter
    var filteredGigs: [GigModel] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return gigs.filter { gig in
            let matchesCategory = selectedCategory == nil || gig.category == selectedCategory
            let matchesSearch = query.isEmpty
                || gig.title.lowercased().contains(query)
                || gig.sellerName.lowercased().contains(query)
                || gig.keywords.contains { $0.lowercased().contains(query) }
            return matchesCategory && matchesSearch
        }
    }

    func gig(id: String) -> GigModel? { gigs.first { $0.id == id } }

    func start() {
        guard gigsListener == nil else { return }
        let db = Firestore.firestore()

        gigsListener = db.collection("services").addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            self.isLoading = false
            if let error {
                self.errorMessage = error.localizedDescription
                print("🔥 Firestore services error:", error)
                return
            }
            self.errorMessage = nil
            self.gigs = (snapshot?.documents ?? [])
                .compactMap { GigModel(id: $0.documentID, data: $0.data()) }
                .filter(\.isVisible)
                .sorted { $0.order < $1.order }
        }

        pagesListener = db.collection("pages").addSnapshotListener { [weak self] snapshot, _ in
            self?.pages = (snapshot?.documents ?? [])
                .map { SitePage(id: $0.documentID, data: $0.data()) }
                .filter(\.isVisible)
                .sorted { $0.order < $1.order }
        }

        categoriesListener = db.collection("admin_settings").document("categories")
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.adminCategories = snapshot?.data()?["list"] as? [String] ?? []
            }
    }

    /// services/{id}.views +1, once per app session (website ViewTracker; rules only let signed-in users write)
    func trackView(_ gigID: String) {
        guard !trackedViews.contains(gigID) else { return }
        trackedViews.insert(gigID)
        Firestore.firestore().collection("services").document(gigID).updateData(["views": FieldValue.increment(Int64(1))])
    }
    @ObservationIgnored private var trackedViews = Set<String>()

    /// Public reviews for the detail window (services/{id}/reviews, newest first)
    func reviews(for gigID: String) async -> [GigReview] {
        let snap = try? await Firestore.firestore().collection("services").document(gigID)
            .collection("reviews").order(by: "createdAt", descending: true).limit(to: 30).getDocuments()
        return (snap?.documents ?? []).map { GigReview(id: $0.documentID, data: $0.data()) }
    }

    func stop() {
        gigsListener?.remove(); gigsListener = nil
        categoriesListener?.remove(); categoriesListener = nil
        pagesListener?.remove(); pagesListener = nil
    }
}

/// pages/{id}: content pages or external links managed in the website admin (/admin/pages)
struct SitePage: Identifiable, Hashable {
    let id: String
    let title: String
    let slug: String
    let isLink: Bool
    let html: String
    let linkUrl: String
    let isVisible: Bool
    let order: Int

    init(id: String, data: [String: Any]) {
        self.id = id
        title = data["title"] as? String ?? "Page"
        slug = data["slug"] as? String ?? ""
        isLink = (data["pageType"] as? String) == "link"
        html = data["content"] as? String ?? ""
        linkUrl = data["linkUrl"] as? String ?? ""
        isVisible = data["isVisible"] as? Bool ?? true
        order = FS.int(data["order"]) ?? 0
    }

    /// Where it lives on the website
    var webURL: URL? {
        isLink ? URL(string: linkUrl) : URL(string: "https://reskindev.com/\(slug)")
    }
}
