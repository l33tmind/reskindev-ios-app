import SwiftUI

// Models → Models/       Firestore stores + order/chat writes → Services/
// Colors, radius, CachedImage, skeleton, buttons → DesignSystem/
// Windows: gig detail → Views/GigDetail, inbox → Views/Inbox, profile → Views/Profile

// MARK: - Main window: search + 3D carousel, dock as an ornament.
// The sidebar and orders panels are separate windows (see ReskindevproApp) placed to its left and right,
// so each one can be grabbed, pulled closer, moved or closed on its own.
struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(SessionStore.self) private var session
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        CenterStageView()
            .frame(width: 900)
            .padding(.horizontal, 12)
            .padding(.vertical, 40)
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
            .onAppear {
                // Launch layout: menu on the left, orders on the right
                if !appModel.showSidebar { openWindow(id: WindowID.sidebar, value: WindowID.single) }
                if !appModel.showOrders { openWindow(id: WindowID.orders, value: WindowID.single) }
            }
    }
}

/// Keeps AppModel in sync with whether a side panel window is open (people can close it with the window controls)
struct PanelWindow<Content: View>: View {
    enum Kind { case sidebar, orders }
    let kind: Kind
    @ViewBuilder let content: Content
    @Environment(AppModel.self) private var appModel

    var body: some View {
        content
            .onAppear { set(true) }
            .onDisappear { set(false) }
    }

    private func set(_ open: Bool) {
        switch kind {
        case .sidebar: appModel.showSidebar = open
        case .orders: appModel.showOrders = open
        }
    }
}

// MARK: - Bottom Dock (shown as an ornament)
struct SpatialBottomDock: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(AppModel.self) private var appModel
    @Environment(ChatStore.self) private var chat
    @Environment(GigStore.self) private var gigStore
    @Environment(SessionStore.self) private var session
    @State private var showNotifications = false

    var body: some View {
        HStack(spacing: 28) {
            DockTabItem(icon: "sidebar.leading", text: "Menu", isActive: appModel.showSidebar) {
                toggle(WindowID.sidebar, isOpen: appModel.showSidebar)
            }
            DockTabItem(icon: "house.fill", text: "Home", isActive: true) {
                gigStore.searchText = ""
                gigStore.selectedCategory = nil
            }
            DockTabItem(icon: "magnifyingglass", text: "Search") {
                appModel.searchFocusRequest += 1
            }
            DockTabItem(icon: "doc.text", text: "Orders", isActive: appModel.showOrders) {
                toggle(WindowID.orders, isOpen: appModel.showOrders)
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

    /// Opens a side panel next to the main window, or closes it
    private func toggle(_ id: String, isOpen: Bool) {
        if isOpen {
            dismissWindow(id: id, value: WindowID.single)
        } else {
            openWindow(id: id, value: WindowID.single)
        }
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
