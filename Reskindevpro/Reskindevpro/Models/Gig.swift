import Foundation

// MARK: - Gig model (mirrors lib/models/gig_model.dart in the Flutter app)

struct GigPackage: Hashable, Identifiable {
    let id: String
    let name: String
    let price: Double
    let description: String
    let deliveryDays: Int
    let features: [String]       // legacy list
    let featureChecks: [Bool]    // 1:1 with GigModel.masterFeatures
}

struct GigModel: Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let description: String      // plain text (HTML stripped)
    let imageUrl: String
    let images: [String]
    let galleryImages: [String]
    let youtubeUrl: String?
    let sellerName: String
    let authorId: String
    let averageRating: Double
    let reviewCount: Int
    let keywords: [String]
    let masterFeatures: [String]
    let status: String
    let isVacation: Bool
    /// Starred in the website admin (/admin/services)
    let isFeatured: Bool
    let order: Int
    let packages: [GigPackage]

    /// Starting price = first package (same as Flutter `basePrice`)
    var price: Double { packages.first?.price ?? 0 }

    var ratingText: String {
        reviewCount > 0
            ? String(format: "%.1f · %ld Reviews", averageRating, reviewCount)
            : "New"
    }

    /// All images for the detail gallery, without duplicates
    var allImages: [String] {
        var seen = Set<String>()
        return ([imageUrl] + images + galleryImages).filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// Same rule as Flutter `isVisible`
    var isVisible: Bool { (status == "active" || status == "published") && !isVacation && !isDeleted }
    let isDeleted: Bool

    /// Features included in a package (master list + checks, or legacy list)
    func features(for package: GigPackage) -> [(name: String, included: Bool)] {
        if !masterFeatures.isEmpty {
            return masterFeatures.enumerated().map { i, name in
                (name, i < package.featureChecks.count ? package.featureChecks[i] : false)
            }
        }
        return package.features.map { ($0, true) }
    }

    init?(id: String, data: [String: Any]) {
        func num(_ key: String) -> Double? { (data[key] as? NSNumber)?.doubleValue }

        let images = data["images"] as? [String] ?? []
        let legacyImage = data["imageUrl"] as? String ?? ""

        self.id = id
        self.title = data["title"] as? String ?? ""
        self.category = data["category"] as? String ?? ""
        self.description = Self.plainText(fromHTML: data["description"] as? String ?? "")
        self.imageUrl = legacyImage.isEmpty ? (images.first ?? "") : legacyImage
        self.images = images
        self.galleryImages = data["galleryImages"] as? [String] ?? []
        let yt = data["youtubeUrl"] as? String
        self.youtubeUrl = (yt?.isEmpty ?? true) ? nil : yt
        self.sellerName = data["authorName"] as? String ?? ""
        self.authorId = data["authorId"] as? String ?? ""
        self.averageRating = num("rating") ?? num("averageRating") ?? 0
        self.reviewCount = Int(num("reviewCount") ?? num("reviews") ?? 0)
        self.keywords = data["keywords"] as? [String] ?? data["tags"] as? [String] ?? []
        self.masterFeatures = data["masterFeatures"] as? [String] ?? []
        self.status = data["status"] as? String ?? "active"
        self.isVacation = data["isVacation"] as? Bool ?? false
        self.isFeatured = data["isFeatured"] as? Bool ?? false
        self.isDeleted = data["isDeleted"] as? Bool ?? false
        self.order = Int(num("order") ?? 0)
        self.packages = (data["packages"] as? [[String: Any]] ?? []).enumerated().map { index, p in
            GigPackage(
                id: (p["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "pkg\(index)",
                name: p["name"] as? String ?? "Basic",
                price: (p["price"] as? NSNumber)?.doubleValue ?? 0,
                description: p["description"] as? String ?? "",
                deliveryDays: (p["deliveryDays"] as? NSNumber)?.intValue ?? 3,
                features: p["features"] as? [String] ?? [],
                featureChecks: p["featureChecks"] as? [Bool] ?? []
            )
        }
        if title.isEmpty { return nil }
    }

    /// Descriptions can be HTML (from the web editor) — turn them into readable text.
    static func plainText(fromHTML html: String) -> String {
        var s = html
        for tag in ["<br>", "<br/>", "<br />", "</p>", "</li>", "</h1>", "</h2>", "</h3>", "</div>"] {
            s = s.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }
        s = s.replacingOccurrences(of: "<li>", with: "• ", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'"]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        s = s.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
