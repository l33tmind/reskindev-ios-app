import AppIntents
import Observation

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
    }
}
