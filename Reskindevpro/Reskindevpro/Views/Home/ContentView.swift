import SwiftUI

// Models → Models/       Firestore stores + order/chat writes → Services/
// Colors, radius, CachedImage, skeleton, buttons → DesignSystem/
// Windows: gig detail → Views/GigDetail, inbox → Views/Inbox, profile → Views/Profile

// MARK: - Main window: sidebar · 3D carousel · orders, with the dock as an ornament
struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(SessionStore.self) private var session

    var body: some View {
        HStack(alignment: .center, spacing: 40) {

            // Panel A: Left Sidebar (Angled Inward)
            LeftSidebarView()
                .frame(width: 320, height: 720)
                .rotation3DEffect(.degrees(12), axis: (x: 0, y: 1, z: 0))
                .offset(z: 50)

            // Panel B: Center Stage (Floating Filter & 3D Carousel)
            CenterStageView()
                .frame(width: 900)

            // Panel C: Right Workspace (Angled Inward)
            if appModel.showOrders {
                RightOrdersView()
                    .frame(width: 440, height: 720)
                    .rotation3DEffect(.degrees(-12), axis: (x: 0, y: 1, z: 0))
                    .offset(z: 50)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
        .animation(.spring(duration: 0.4), value: appModel.showOrders)
        // Admin → Users → Block
        .overlay(alignment: .top) {
            if session.isBlockedByAdmin {
                Label("Your account has been suspended by Reskindev. Contact support to restore ordering and messaging.",
                      systemImage: "exclamationmark.octagon.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.85), in: Capsule())
                    .offset(y: -10)
            }
        }
        // Bottom dock as a real visionOS ornament: follows the window, sits below it
        .ornament(attachmentAnchor: .scene(.bottom), contentAlignment: .top) {
            SpatialBottomDock()
                .padding(.top, 20)
        }
    }
}

// MARK: - Bottom Dock (shown as an ornament)
struct SpatialBottomDock: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(AppModel.self) private var appModel
    @Environment(ChatStore.self) private var chat
    @Environment(GigStore.self) private var gigStore
    @Environment(SessionStore.self) private var session
    @State private var showNotifications = false

    var body: some View {
        HStack(spacing: 28) {
            DockTabItem(icon: "house.fill", text: "Home", isActive: true) {
                gigStore.searchText = ""
                gigStore.selectedCategory = nil
            }
            DockTabItem(icon: "magnifyingglass", text: "Search") {
                appModel.searchFocusRequest += 1
            }
            DockTabItem(icon: "doc.text", text: "Orders", isActive: appModel.showOrders) {
                appModel.showOrders.toggle()
            }
            DockTabItem(icon: "tray", text: "Inbox", badge: chat.unreadTotal) {
                openWindow(id: WindowID.inbox, value: WindowID.single)
            }
            ToggleImmersiveSpaceButton()
            if session.isSignedIn {
                DockTabItem(icon: "bell", text: "Alerts", badge: session.unreadNotifications) {
                    showNotifications = true
                }
            }
            DockTabItem(icon: "person", text: "Profile") {
                appModel.profileTab = .profile
                openWindow(id: WindowID.profile, value: WindowID.single)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .glassBackgroundEffect(in: Capsule())
        .sheet(isPresented: $showNotifications) { NotificationsView() }
    }
}

struct DockTabItem: View {
    let icon: String
    let text: String
    var isActive: Bool = false
    var badge: Int = 0
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 {
                            Text(badge > 99 ? "99+" : "\(badge)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Color.red, in: Capsule())
                                .offset(x: 12, y: -8)
                        }
                    }
                Text(text)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(isActive ? Color.white : Color.secondary)
            .frame(minWidth: 72, minHeight: 72)
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: Radius.small))
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityLabel(badge > 0 ? "\(text), \(badge) unread" : text)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

#Preview(windowStyle: .plain) {
    ContentView()
        .environment(GigStore())
        .environment(SessionStore())
        .environment(ChatStore())
        .environment(SellerStore())
        .environment(AppModel())
}
