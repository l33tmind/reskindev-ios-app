import Foundation
import WidgetKit
import FirebaseFirestore

/// Keeps the Order Board and Desk widgets current: every active order (buying and selling),
/// unread messages and seller earnings, saved for the widgets to read
@MainActor
enum WidgetSync {
    private static var lastSaved: Data?

    static func refresh(session: SessionStore, chat: ChatStore, seller: SellerStore) async {
        var snapshot = WidgetSnapshot()
        defer { save(snapshot) }
        guard let uid = session.uid else { return }

        snapshot.signedIn = true
        snapshot.name = session.displayName
        snapshot.unreadMessages = chat.unreadTotal

        // Both sides, like My Orders' Buying + Selling (same queries as the app)
        let orders = Firestore.firestore().collection("orders")
        async let bought = orders.whereFilter(.orFilter([
            .whereField("userId", isEqualTo: uid), .whereField("clientUid", isEqualTo: uid),
        ])).getDocuments()
        async let sold = orders.whereField("authorId", isEqualTo: uid).getDocuments()
        guard let docs = try? await bought.documents + sold.documents else { return }

        var seen = Set<String>()
        let active = docs
            .filter { seen.insert($0.documentID).inserted }
            .map { OrderModel(id: $0.documentID, data: $0.data()) }
            .filter { !$0.isCompleted && $0.status != "cancelled" }
            .sorted { $0.createdAt > $1.createdAt }

        snapshot.orders = active.prefix(8).map { order in
            WidgetSnapshot.Order(
                id: order.id,
                title: order.gigTitle,
                status: order.statusLabel,
                isBuyer: order.isBuyer(uid),
                dueDate: order.isTimerRunning ? order.dueDate : nil,
                nextStep: order.nextActionTitle(for: uid).map { "Your turn: \($0.lowercased())" }
            )
        }

        // Sellers see their money on the Desk widget
        if docs.contains(where: { $0.data()["authorId"] as? String == uid }) {
            await seller.loadEarnings(session: session)
            snapshot.available = seller.earnings.available
            snapshot.pendingClearance = seller.earnings.pendingClearance
        }
    }

    /// Writes only when something changed, then asks the widgets to redraw
    private static func save(_ snapshot: WidgetSnapshot) {
        var comparable = snapshot
        comparable.updatedAt = .distantPast
        let data = try? JSONEncoder().encode(comparable)
        guard data != lastSaved else { return }
        lastSaved = data
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
