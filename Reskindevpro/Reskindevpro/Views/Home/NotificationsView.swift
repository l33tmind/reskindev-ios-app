import SwiftUI

/// Bell list: admin order updates + broadcasts sent from the website admin
struct NotificationsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Notifications").font(.title.weight(.semibold))
                Spacer()
                if session.unreadNotifications > 0 {
                    Button("Mark all read") { session.markAllNotificationsRead() }
                        .buttonStyle(.bordered)
                }
                CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
            }

            if session.notifications.isEmpty {
                ContentUnavailableView("You're all caught up", systemImage: "bell.slash",
                                       description: Text("Order updates, payments and deliveries show up here."))
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(session.notifications) { item in
                            Button {
                                open(item)
                            } label: {
                                row(item)
                            }
                            .buttonStyle(.plain)
                            .hoverEffect(.highlight)
                        }
                    }
                }
            }
        }
        .padding(28)
        .frame(width: 560, height: 640)
        .sheetPresence()
    }

    /// Icon + colour for each kind of notification (same set as the website and the iOS app)
    private func style(for item: AppNotification) -> (icon: String, color: Color) {
        var type = item.type
        if type == "order", item.title.localizedCaseInsensitiveContains("complete") { type = "completed" }
        switch type {
        case "order": return ("bag.fill", .orange)
        case "payment": return ("checkmark.shield.fill", .green)
        case "requirements": return ("list.clipboard.fill", .blue)
        case "started": return ("play.circle.fill", .blue)
        case "delivery": return ("shippingbox.fill", .purple)
        case "revision": return ("arrow.counterclockwise", .orange)
        case "completed": return ("checkmark.circle.fill", .green)
        case "review": return ("star.fill", .yellow)
        case "broadcast": return ("megaphone.fill", Color.brandGreen)
        default: return ("bell.fill", Color.brandGreen)
        }
    }

    private func pill(_ text: String, strong: Bool) -> some View {
        Text(text)
            .font(.caption2.weight(strong ? .bold : .semibold))
            .monospacedDigit()
            .foregroundStyle(strong ? Color.primary : Color.secondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.white.opacity(strong ? 0.14 : 0.08), in: Capsule())
    }

    private func row(_ item: AppNotification) -> some View {
        let look = style(for: item)
        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: look.icon)
                .font(.title3)
                .foregroundStyle(look.color)
                .frame(width: 48, height: 48)
                .background(look.color.opacity(item.read ? 0.14 : 0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.title).font(.headline)
                    Spacer()
                    if let date = item.createdAt {
                        Text(date, format: .relative(presentation: .numeric, unitsStyle: .abbreviated))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if !item.read {
                        Circle().fill(look.color).frame(width: 9, height: 9)
                            .accessibilityLabel("Unread")
                    }
                }
                Text(item.message).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                if !item.orderNumber.isEmpty || !item.invoiceNumber.isEmpty {
                    HStack(spacing: 6) {
                        if !item.orderNumber.isEmpty { pill("Order \(item.orderNumber)", strong: true) }
                        if !item.invoiceNumber.isEmpty { pill(item.invoiceNumber, strong: false) }
                    }
                    .padding(.top, 3)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(item.read ? Color.white.opacity(0.04) : look.color.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
            .stroke(item.read ? Color.white.opacity(0.08) : look.color.opacity(0.35), lineWidth: 1))
    }

    /// Website links: /profile/orders, /freelancer → orders panel
    private func open(_ item: AppNotification) {
        session.markRead(item)
        if item.link.contains("orders") || item.link.contains("freelancer") || item.link.contains("inbox") {
            openWindow(id: WindowID.orders, value: WindowID.single)
            dismiss()
        }
    }
}
