import SwiftUI

// Models → Models/       Firestore stores + order/chat writes → Services/
// Colors, radius, CachedImage, skeleton, buttons → DesignSystem/
// Windows: gig detail → Views/GigDetail, inbox → Views/Inbox, profile → Views/Profile

// MARK: - Main window: sidebar · 3D carousel · orders, with the dock as an ornament.
// The side panels start together like a cockpit; each has a grab bar to drag it anywhere in the window
// (pinch and move your hand toward you to pull it closer), pop it out into its own window, or hide it.
struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(SessionStore.self) private var session
    @Environment(ChatStore.self) private var chat
    @Environment(\.openWindow) private var openWindow
    private let push = PushService.shared

    var body: some View {
        @Bindable var appModel = appModel

        HStack(alignment: .center, spacing: 40) {
            // Panel A: Left Sidebar (angled inward)
            if appModel.sidebarDocked {
                DraggablePanel(title: "Menu", offset: $appModel.sidebarOffset, baseDepth: Tilt.depth,
                               onPopOut: { popOut(sidebar: true) },
                               onClose: { withAnimation { appModel.sidebarDocked = false } }) {
                    LeftSidebarView()
                        .frame(width: 320, height: 720)
                        .panelTilt(yaw: Tilt.yaw)
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            // Panel B: Center Stage (search + 3D carousel), leaning back like a monitor
            CenterStageView()
                .frame(width: 900)
                .rotation3DEffect(.degrees(Tilt.pitch), axis: (x: 1, y: 0, z: 0), anchor: .bottom)
                .offset(z: Tilt.centerDepth)

            // Panel C: Orders (angled inward)
            if appModel.ordersDocked {
                DraggablePanel(title: "Orders", offset: $appModel.ordersOffset, baseDepth: Tilt.depth,
                               onPopOut: { popOut(sidebar: false) },
                               onClose: { withAnimation { appModel.ordersDocked = false } }) {
                    RightOrdersView()
                        .frame(width: 440, height: 720)
                        .panelTilt(yaw: -Tilt.yaw)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
        .animation(.spring(duration: 0.4), value: appModel.sidebarDocked)
        .animation(.spring(duration: 0.4), value: appModel.ordersDocked)
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
        // Tapped a chat push → open that WorkStream
        .onChange(of: push.pendingChatID) {
            guard let chatID = push.pendingChatID else { return }
            chat.activeChatID = chatID
            openWindow(id: WindowID.inbox, value: WindowID.single)
            push.pendingChatID = nil
        }
    }

    /// Takes a docked panel out of the main window into its own window the user can place anywhere in the room
    private func popOut(sidebar: Bool) {
        withAnimation {
            if sidebar { appModel.sidebarDocked = false } else { appModel.ordersDocked = false }
        }
        openWindow(id: sidebar ? WindowID.sidebar : WindowID.orders, value: WindowID.single)
    }
}

/// Cockpit layout: side panels turn in toward the viewer and everything leans back slightly
enum Tilt {
    /// Side panels turn toward you
    static let yaw: Double = 22
    /// Top edge leans away
    static let pitch: Double = 6
    /// Pushes panels forward so their far edges stay in front of the window plane (anything behind it is clipped)
    static let depth: Double = 140
    static let centerDepth: Double = 40
}

extension View {
    /// Turn (yaw) toward the viewer, then lean back (pitch) from the bottom edge
    func panelTilt(yaw: Double) -> some View {
        self
            .rotation3DEffect(.degrees(yaw), axis: (x: 0, y: 1, z: 0))
            .rotation3DEffect(.degrees(Tilt.pitch), axis: (x: 1, y: 0, z: 0), anchor: .bottom)
    }
}

/// A docked side panel with a visionOS-style grab bar underneath:
/// drag the bar to move the panel (x / y, and toward / away from you), ↺ resets, ⧉ pops it out, ✕ hides it.
struct DraggablePanel<Content: View>: View {
    let title: String
    @Binding var offset: AppModel.PanelOffset
    var baseDepth: Double = 0
    var onPopOut: () -> Void
    var onClose: () -> Void
    @ViewBuilder let content: Content

    @State private var dragStart: AppModel.PanelOffset?
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 14) {
            content
            grabBar
        }
        .scaleEffect(isDragging ? 1.02 : 1)
        .offset(x: offset.x, y: offset.y)
        .offset(z: baseDepth + offset.z)
        .animation(.interactiveSpring, value: offset)
        .animation(.spring(duration: 0.25), value: isDragging)
    }

    private var grabBar: some View {
        HStack(spacing: 6) {
            if offset.isMoved {
                barButton("arrow.counterclockwise", "Put \(title) back") {
                    withAnimation(.spring(duration: 0.5)) { offset = .init() }
                }
            }
            Capsule()
                .fill(.white.opacity(isDragging ? 0.95 : 0.6))
                .frame(width: isDragging ? 150 : 120, height: 10)
                .frame(width: 170, height: 44)
                .contentShape(Rectangle())
                .hoverEffect(.highlight)
                .gesture(drag)
                .accessibilityLabel("Move \(title)")
                .accessibilityHint("Drag to move the panel. Move your hand toward you to bring it closer.")
            barButton("rectangle.portrait.on.rectangle.portrait", "Open \(title) in its own window", action: onPopOut)
            barButton("xmark", "Hide \(title)", action: onClose)
        }
        .padding(.horizontal, 6)
        .glassBackgroundEffect(in: Capsule())
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStart == nil { dragStart = offset }
                isDragging = true
                let start = dragStart ?? offset
                let t = value.translation3D
                offset = .init(x: start.x + t.x,
                               y: start.y + t.y,
                               z: min(320, max(0, start.z + t.z)))
            }
            .onEnded { _ in
                dragStart = nil
                isDragging = false
            }
    }

    private func barButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.callout.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityLabel(label)
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
            DockTabItem(icon: "sidebar.leading", text: "Menu", isActive: appModel.sidebarVisible) {
                toggle(sidebar: true)
            }
            DockTabItem(icon: "house.fill", text: "Home", isActive: true) {
                gigStore.searchText = ""
                gigStore.selectedCategory = nil
            }
            DockTabItem(icon: "magnifyingglass", text: "Search") {
                appModel.searchFocusRequest += 1
            }
            DockTabItem(icon: "doc.text", text: "Orders", isActive: appModel.ordersVisible) {
                toggle(sidebar: false)
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

    /// Hides a panel wherever it is (docked or popped out), or brings it back docked in the main window
    private func toggle(sidebar: Bool) {
        let windowOpen = sidebar ? appModel.showSidebar : appModel.showOrders
        let docked = sidebar ? appModel.sidebarDocked : appModel.ordersDocked
        if windowOpen {
            dismissWindow(id: sidebar ? WindowID.sidebar : WindowID.orders, value: WindowID.single)
        } else {
            withAnimation {
                if sidebar { appModel.sidebarDocked = !docked } else { appModel.ordersDocked = !docked }
            }
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
