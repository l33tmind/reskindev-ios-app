import AppIntents
import Observation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

// MARK: - Siri: "Hey Siri, find video editing on Reskindev" → "What's your budget?" → "Under 20 dollars"
// Siri phrases can carry only one spoken value, so the category is in the phrase and Siri asks for the budget.
// The app opens, filters Explore to that category + budget, and opens the best-rated matching gig.

/// What Siri asked for; ContentView picks it up and runs it in the app's live stores
struct ServiceSearchRequest: Equatable {
    let keywords: [String]
    let maxPrice: Double?
}

@Observable
final class SiriBridge {
    static let shared = SiriBridge()
    var pending: ServiceSearchRequest?
    /// "Order a service": open this gig with its checkout already up
    var pendingCheckoutGigID: String?
    /// "Show my orders / messages / …"
    var pendingScreen: AppScreen?
}

/// Service types people say out loud; each maps onto the admin categories by keyword
enum SpokenCategory: String, AppEnum {
    case videoEditing, mobileApps, webDevelopment, marketing, design, arVR, writing

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Service"
    static let caseDisplayRepresentations: [SpokenCategory: DisplayRepresentation] = [
        .videoEditing: DisplayRepresentation(title: "Video Editing", synonyms: ["video editor", "video", "youtube editing", "video edit"]),
        .mobileApps: DisplayRepresentation(title: "Mobile Apps", synonyms: ["app developer", "mobile app", "iOS app", "android app", "app"]),
        .webDevelopment: DisplayRepresentation(title: "Web Development", synonyms: ["website", "web developer", "web design"]),
        .marketing: DisplayRepresentation(title: "Marketing", synonyms: ["app promotion", "SEO", "social media"]),
        .design: DisplayRepresentation(title: "Design", synonyms: ["designer", "logo", "graphic design", "UI design"]),
        .arVR: DisplayRepresentation(title: "AR and VR", synonyms: ["Vision Pro app", "augmented reality", "virtual reality", "AR app"]),
        .writing: DisplayRepresentation(title: "Writing", synonyms: ["writer", "content writing", "copywriting"]),
    ]

    /// Words matched against category names first, then used as a search
    var keywords: [String] {
        switch self {
        case .videoEditing: ["video", "edit"]
        case .mobileApps: ["mobile", "app", "ios", "android"]
        case .webDevelopment: ["web", "site"]
        case .marketing: ["market", "seo", "social", "promotion"]
        case .design: ["design", "logo", "ui"]
        case .arVR: ["ar", "vr", "vision", "augmented"]
        case .writing: ["writ", "content"]
        }
    }
}

enum SpokenBudget: String, AppEnum {
    case under10, under20, under50, under100, under200, under500, any

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Budget"
    static let caseDisplayRepresentations: [SpokenBudget: DisplayRepresentation] = [
        .under10: DisplayRepresentation(title: "Under $10", synonyms: ["10 dollars", "under 10", "10"]),
        .under20: DisplayRepresentation(title: "Under $20", synonyms: ["20 dollars", "under 20", "20"]),
        .under50: DisplayRepresentation(title: "Under $50", synonyms: ["50 dollars", "under 50", "50"]),
        .under100: DisplayRepresentation(title: "Under $100", synonyms: ["100 dollars", "under 100", "100"]),
        .under200: DisplayRepresentation(title: "Under $200", synonyms: ["200 dollars", "under 200", "200"]),
        .under500: DisplayRepresentation(title: "Under $500", synonyms: ["500 dollars", "under 500", "500"]),
        .any: DisplayRepresentation(title: "Any budget", synonyms: ["any", "no limit", "doesn't matter", "any price"]),
    ]

    var maxPrice: Double? {
        switch self {
        case .under10: 10
        case .under20: 20
        case .under50: 50
        case .under100: 100
        case .under200: 200
        case .under500: 500
        case .any: nil
        }
    }
}

struct FindServiceIntent: AppIntent {
    static let title: LocalizedStringResource = "Find a Service"
    static let description = IntentDescription("Finds a Reskindev service by type and budget and opens the best match.")
    static let openAppWhenRun = true

    @Parameter(title: "Service", requestValueDialog: "What kind of service are you looking for?")
    var category: SpokenCategory

    @Parameter(title: "Budget", requestValueDialog: "What's your budget?")
    var budget: SpokenBudget

    static var parameterSummary: some ParameterSummary {
        Summary("Find \(\.$category) with budget \(\.$budget)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        SiriBridge.shared.pending = ServiceSearchRequest(keywords: category.keywords, maxPrice: budget.maxPrice)
        let what = SpokenCategory.caseDisplayRepresentations[category]?.title ?? "services"
        let limit = budget.maxPrice.map { " under $\(Int($0))" } ?? ""
        return .result(dialog: "Opening \(what)\(limit) on Reskindev.")
    }
}

// MARK: - Shared data for intents that run without opening the app (Siri answers in place)

@MainActor
enum IntentData {
    /// Siri can launch the app in the background, before the SwiftUI App sets Firebase up
    static func ensureFirebase() {
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
    }

    static func gigs() async throws -> [GigModel] {
        ensureFirebase()
        let snap = try await Firestore.firestore().collection("services").getDocuments()
        return snap.documents.compactMap { GigModel(id: $0.documentID, data: $0.data()) }
            .filter(\.isVisible)
            .sorted { $0.order < $1.order }
    }

    static var uid: String? {
        ensureFirebase()
        return Auth.auth().currentUser?.uid
    }
}

// MARK: - A gig Siri can talk about ("Save a service", "Order a service")

struct GigEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Service"
    static let defaultQuery = GigQuery()

    let id: String
    let title: String
    let seller: String
    let price: Double

    init(_ gig: GigModel) {
        id = gig.id
        title = gig.title
        seller = gig.sellerName
        price = gig.price
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(seller) · from $\(Int(price))")
    }
}

struct GigQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [GigEntity] {
        try await IntentData.gigs().filter { identifiers.contains($0.id) }.map(GigEntity.init)
    }

    /// Spoken or typed words matched against title, seller, category and keywords
    func entities(matching string: String) async throws -> [GigEntity] {
        let words = string.lowercased().split(separator: " ").map(String.init).filter { $0.count > 2 }
        let all = try await IntentData.gigs()
        let hits = all.filter { gig in
            let text = ([gig.title, gig.sellerName, gig.category] + gig.keywords).joined(separator: " ").lowercased()
            return words.contains { text.contains($0) }
        }
        return Array(hits.prefix(8)).map(GigEntity.init)
    }

    /// What Siri offers when it asks "Which service?": your recently viewed first, then the top picks
    func suggestedEntities() async throws -> [GigEntity] {
        let all = try await IntentData.gigs()
        let recent = (UserDefaults.standard.stringArray(forKey: "recentGigIDs") ?? []).compactMap { id in all.first { $0.id == id } }
        var seen = Set<String>()
        return (recent + all).filter { seen.insert($0.id).inserted }.prefix(8).map(GigEntity.init)
    }
}

// MARK: - Data retrieval: "What's my order status on Reskindev?"

struct OrderStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Check My Orders"
    static let description = IntentDescription("Tells you where your active Reskindev orders stand and when they're due.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let uid = IntentData.uid else {
            return .result(dialog: "Open Reskindev and sign in first, then ask me again.")
        }
        let orders = Firestore.firestore().collection("orders")
        // Orders you bought and orders on your gigs (same queries the app uses)
        async let bought = orders.whereFilter(.orFilter([
            .whereField("userId", isEqualTo: uid), .whereField("clientUid", isEqualTo: uid),
        ])).getDocuments()
        async let sold = orders.whereField("authorId", isEqualTo: uid).getDocuments()
        let docs = try await bought.documents + sold.documents

        var seen = Set<String>()
        let active = docs
            .filter { seen.insert($0.documentID).inserted }
            .map { OrderModel(id: $0.documentID, data: $0.data()) }
            .filter { !$0.isCompleted && $0.status != "cancelled" }
            .sorted { $0.createdAt > $1.createdAt }

        guard !active.isEmpty else {
            return .result(dialog: "You have no active orders on Reskindev right now.")
        }
        let lines = active.prefix(3).map { order -> String in
            var line = "\(order.gigTitle): \(order.statusLabel)"
            if order.isTimerRunning {
                let left = order.dueDate.timeIntervalSinceNow
                let days = Int(abs(left) / 86_400), hours = Int(abs(left).truncatingRemainder(dividingBy: 86_400) / 3_600)
                line += left < 0 ? ", late by \(days) days \(hours) hours" : ", due in \(days) days \(hours) hours"
            }
            if order.isBuyer(uid), order.nextAction(for: uid) != nil { line += ". It's your turn." }
            return line
        }
        let intro = active.count == 1 ? "You have one active order." : "You have \(active.count) active orders."
        return .result(dialog: "\(intro) \(lines.joined(separator: ". "))")
    }
}

// MARK: - Direct action: "Save a service on Reskindev"

struct SaveServiceIntent: AppIntent {
    static let title: LocalizedStringResource = "Save a Service"
    static let description = IntentDescription("Adds a Reskindev service to your wishlist.")

    @Parameter(title: "Service", requestValueDialog: "Which service should I save?")
    var gig: GigEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let uid = IntentData.uid else {
            return .result(dialog: "Open Reskindev and sign in first, then ask me again.")
        }
        try await Firestore.firestore().collection("users").document(uid)
            .updateData(["savedGigs": FieldValue.arrayUnion([gig.id])])
        return .result(dialog: "Saved \(gig.title) to your Reskindev wishlist.")
    }
}

// MARK: - Direct action: "Order a service on Reskindev" → opens checkout; you confirm in the app

struct OrderServiceIntent: AppIntent {
    static let title: LocalizedStringResource = "Order a Service"
    static let description = IntentDescription("Opens checkout for a Reskindev service so you can review and place the order.")
    static let openAppWhenRun = true

    @Parameter(title: "Service", requestValueDialog: "Which service would you like to order?")
    var gig: GigEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        SiriBridge.shared.pendingCheckoutGigID = gig.id
        return .result(dialog: "Opening checkout for \(gig.title). Review it and tap Place Order.")
    }
}

// MARK: - Open a screen: "Show my orders in Reskindev"

enum AppScreen: String, AppEnum {
    case orders, messages, saved, profile, showroom, explore

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Screen"
    static let caseDisplayRepresentations: [AppScreen: DisplayRepresentation] = [
        .orders: DisplayRepresentation(title: "My Orders", synonyms: ["orders", "order list"]),
        .messages: DisplayRepresentation(title: "Messages", synonyms: ["inbox", "chats", "chat"]),
        .saved: DisplayRepresentation(title: "Saved Services", synonyms: ["wishlist", "favorites", "saved"]),
        .profile: DisplayRepresentation(title: "Profile", synonyms: ["account", "my profile"]),
        .showroom: DisplayRepresentation(title: "3D Showroom", synonyms: ["showroom", "3D"]),
        .explore: DisplayRepresentation(title: "Explore", synonyms: ["home", "marketplace"]),
    ]
}

struct OpenScreenIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Reskindev"
    static let description = IntentDescription("Opens a part of Reskindev: orders, messages, saved services, profile or the 3D Showroom.")
    static let openAppWhenRun = true

    @Parameter(title: "Screen", requestValueDialog: "What should I open?")
    var screen: AppScreen

    @MainActor
    func perform() async throws -> some IntentResult {
        SiriBridge.shared.pendingScreen = screen
        return .result()
    }
}

struct ReskindevShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FindServiceIntent(),
            phrases: [
                "Find \(\.$category) on \(.applicationName)",
                "Find me \(\.$category) on \(.applicationName)",
                "Find a \(\.$category) in \(.applicationName)",
                "Search \(.applicationName) for \(\.$category)",
                "Find a service on \(.applicationName)",
            ],
            shortTitle: "Find a Service",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: OrderStatusIntent(),
            phrases: [
                "What's my order status on \(.applicationName)",
                "Check my \(.applicationName) orders",
                "How are my orders on \(.applicationName)",
            ],
            shortTitle: "Check My Orders",
            systemImageName: "shippingbox"
        )
        AppShortcut(
            intent: OrderServiceIntent(),
            phrases: [
                "Order a service on \(.applicationName)",
                "Hire someone on \(.applicationName)",
            ],
            shortTitle: "Order a Service",
            systemImageName: "cart"
        )
        AppShortcut(
            intent: SaveServiceIntent(),
            phrases: [
                "Save a service on \(.applicationName)",
                "Add to my \(.applicationName) wishlist",
            ],
            shortTitle: "Save a Service",
            systemImageName: "heart"
        )
        AppShortcut(
            intent: OpenScreenIntent(),
            phrases: [
                "Open \(\.$screen) in \(.applicationName)",
                "Show my \(\.$screen) on \(.applicationName)",
            ],
            shortTitle: "Open Reskindev",
            systemImageName: "rectangle.on.rectangle"
        )
    }
}
