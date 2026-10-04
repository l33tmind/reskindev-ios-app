import WidgetKit
import SwiftUI

// MARK: - Reskindev widgets for Apple Vision Pro
// Order Board: pin it on a wall; your active orders and deadlines, like a work board.
// Desk widget: next deadline, unread messages and (for sellers) earnings, on your table.
// Both read the snapshot the app saves (Shared/WidgetSnapshot.swift); tapping opens the app.

private let brandGreen = Color(red: 0.11, green: 0.75, blue: 0.45)

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .preview : .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        // The app reloads the widgets whenever orders change; this refresh is just a safety net
        let entry = SnapshotEntry(date: .now, snapshot: .load())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
    }
}

// MARK: Order Board (wall)

struct OrderBoardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OrderBoard", provider: SnapshotProvider()) { entry in
            OrderBoardView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "reskindev://orders"))
        }
        .configurationDisplayName("Order Board")
        .description("Your active orders and deadlines. Pin it on a wall.")
        .supportedFamilies([.systemLarge, .systemExtraLarge, .systemMedium])
        .supportedMountingStyles([.recessed, .elevated])
        .widgetTexture(.paper)
    }
}

struct OrderBoardView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family
    @Environment(\.levelOfDetail) private var levelOfDetail

    private var maxRows: Int { family == .systemMedium ? 2 : family == .systemLarge ? 4 : 6 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Order Board", systemImage: "shippingbox.fill")
                    .font(.headline)
                    .foregroundStyle(brandGreen)
                Spacer()
                if snapshot.unreadMessages > 0 {
                    Label("\(snapshot.unreadMessages)", systemImage: "bubble.left.fill")
                        .font(.subheadline.weight(.bold))
                }
            }

            if !snapshot.signedIn {
                Spacer()
                Text("Open Reskindev and sign in to see your orders.")
                    .font(.title3).foregroundStyle(.secondary)
                Spacer()
            } else if snapshot.orders.isEmpty {
                Spacer()
                Text("No active orders").font(.title2.weight(.bold))
                Text("New orders show up here.").foregroundStyle(.secondary)
                Spacer()
            } else if levelOfDetail == .simplified {
                // Seen from across the room: just the big numbers
                Spacer()
                Text("\(snapshot.orders.count)").font(.system(size: 80, weight: .bold)).foregroundStyle(brandGreen)
                Text(snapshot.orders.count == 1 ? "active order" : "active orders").font(.title2)
                Spacer()
            } else {
                ForEach(snapshot.orders.prefix(maxRows)) { order in
                    OrderRow(order: order)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(4)
    }
}

private struct OrderRow: View {
    let order: WidgetSnapshot.Order

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(order.nextStep != nil ? Color.orange : brandGreen)
                .frame(width: 6)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(order.title).font(.headline).lineLimit(1)
                    Spacer()
                    Text(order.isBuyer ? "Buying" : "Selling")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                HStack {
                    Text(order.status).font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    if let due = order.dueDate {
                        if due > .now {
                            Label { Text(due, style: .relative) } icon: { Image(systemName: "timer") }
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                        } else {
                            Text("Late").font(.subheadline.weight(.bold)).foregroundStyle(.red)
                        }
                    }
                }
                if let next = order.nextStep {
                    Text(next).font(.caption.weight(.semibold)).foregroundStyle(.orange)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: Desk widget (table)

struct DeskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Desk", provider: SnapshotProvider()) { entry in
            DeskView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "reskindev://orders"))
        }
        .configurationDisplayName("Reskindev at a Glance")
        .description("Next deadline, unread messages and earnings. Set it on your desk.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .supportedMountingStyles([.elevated])
        .widgetTexture(.glass)
    }
}

struct DeskView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    /// The order with the closest running deadline
    private var nextDue: WidgetSnapshot.Order? {
        snapshot.orders.filter { $0.dueDate != nil }.min { $0.dueDate! < $1.dueDate! }
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Next deadline", systemImage: "timer").font(.caption.weight(.bold)).foregroundStyle(brandGreen)
                if let order = nextDue, let due = order.dueDate {
                    Text(due, style: .relative)
                        .font(.title.weight(.bold).monospacedDigit())
                        .foregroundStyle(due < .now ? .red : .primary)
                        .minimumScaleFactor(0.6)
                    Text(order.title).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                } else {
                    Text(snapshot.signedIn ? "Nothing due" : "Sign in").font(.title2.weight(.bold))
                }
                Spacer(minLength: 0)
                Label("\(snapshot.unreadMessages) unread", systemImage: "bubble.left.fill")
                    .font(.caption.weight(.semibold))
            }
            if family == .systemMedium, let available = snapshot.available {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Label("Earnings", systemImage: "dollarsign.circle.fill").font(.caption.weight(.bold)).foregroundStyle(brandGreen)
                    Text(available, format: .currency(code: "USD")).font(.title.weight(.bold))
                    Text("available").font(.caption).foregroundStyle(.secondary)
                    if let pending = snapshot.pendingClearance, pending > 0 {
                        Text("+\(pending.formatted(.currency(code: "USD"))) clearing").font(.caption)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

@main
struct ReskindevWidgetBundle: WidgetBundle {
    var body: some Widget {
        OrderBoardWidget()
        DeskWidget()
    }
}

#Preview(as: .systemLarge) {
    OrderBoardWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .preview)
}
