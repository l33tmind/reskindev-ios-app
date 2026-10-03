import SwiftUI

/// Bell list: admin order updates + broadcasts sent from the website admin
struct NotificationsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Notifications").font(.title.weight(.bold))
                Spacer()
                if session.unreadNotifications > 0 {
                    Button("Mark all read") { session.markAllNotificationsRead() }
                        .buttonStyle(.bordered)
                }
                CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
            }

            if session.notifications.isEmpty {
                ContentUnavailableView("No notifications", systemImage: "bell.slash",
                                       description: Text("Order updates and announcements from Reskindev show up here."))
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
    }

    private func row(_ item: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.type == "broadcast" ? "megaphone.fill" : "shippingbox.fill")
                .font(.title3)
                .foregroundStyle(Color.brandGreen)
                .frame(width: 44, height: 44)
                .background(Color.brandGreen.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title).font(.headline)
                    Spacer()
                    if let date = item.createdAt {
                        Text(date, format: .relative(presentation: .numeric, unitsStyle: .abbreviated))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text(item.message).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }
            if !item.read {
                Circle().fill(Color.brandGreen).frame(width: 10, height: 10).padding(.top, 6)
                    .accessibilityLabel("Unread")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(item.read ? 0.03 : 0.08), in: RoundedRectangle(cornerRadius: Radius.small))
    }

    /// Website links: /profile/orders, /freelancer → orders panel
    private func open(_ item: AppNotification) {
        session.markRead(item)
        if item.link.contains("orders") || item.link.contains("freelancer") {
            appModel.showOrders = true
            dismiss()
        }
    }
}
