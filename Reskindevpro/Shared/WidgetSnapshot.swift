import Foundation

// MARK: - What the app hands the Reskindev widgets (Order Board, Desk widget)
// The app writes this JSON into the shared App Group container; the widgets only read it.

struct WidgetSnapshot: Codable {
    struct Order: Codable, Identifiable {
        let id: String
        let title: String
        let status: String
        let isBuyer: Bool
        /// Delivery deadline, while the countdown is running
        let dueDate: Date?
        /// "Your turn: …" text, when the next step is this user's
        let nextStep: String?
    }

    var signedIn = false
    var name = ""
    var orders: [Order] = []
    var unreadMessages = 0
    /// Seller money (nil for buyers)
    var available: Double?
    var pendingClearance: Double?
    var updatedAt = Date()

    static let appGroup = "group.com.reskindevdotcom.reskindev"
    private static let fileName = "widget-snapshot.json"

    private static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?.appending(path: fileName)
    }

    static func load() -> WidgetSnapshot {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return WidgetSnapshot() }
        return snapshot
    }

    func save() {
        guard let url = Self.fileURL, let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Sample data for the widget gallery
    static let preview = WidgetSnapshot(
        signedIn: true, name: "Alex",
        orders: [
            Order(id: "1", title: "Vision Pro app prototype", status: "In Progress", isBuyer: false,
                  dueDate: Date().addingTimeInterval(2 * 86_400 + 5 * 3_600), nextStep: "Your turn: deliver your work"),
            Order(id: "2", title: "YouTube video edit", status: "Delivered", isBuyer: true,
                  dueDate: nil, nextStep: "Your turn: review the delivery"),
            Order(id: "3", title: "Logo design", status: "Waiting for Requirements", isBuyer: true,
                  dueDate: nil, nextStep: "Your turn: submit requirements"),
        ],
        unreadMessages: 3, available: 420, pendingClearance: 180)
}
