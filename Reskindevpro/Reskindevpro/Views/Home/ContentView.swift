import SwiftUI

// Models → Models/       Firestore stores + order/chat writes → Services/
// Colors, radius, CachedImage, skeleton, buttons → DesignSystem/
// Windows: gig detail → Views/GigDetail, orders → Views/Orders (own window, opens beside this one)

// MARK: - Main window: visionOS tab bar (Explore · Messages · Profile)
// The tab bar is the system ornament on the window's leading edge; looking at it expands the labels.
// Home (Explore) opens two real side windows — Menu on the left, My Orders on the right — tilted in like a
// cockpit, each with the system window bar to move or close it. Other tabs close the Menu (it's in Profile)
// and straighten My Orders.
struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(SessionStore.self) private var session
    @Environment(ChatStore.self) private var chat
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    private let push = PushService.shared

    var body: some View {
        @Bindable var appModel = appModel

        TabView(selection: $appModel.selectedTab) {
            Tab("Explore", systemImage: "sparkles.rectangle.stack", value: AppModel.MainTab.explore) {
                ExploreView()
            }
            Tab("Messages", systemImage: "bubble.left.and.bubble.right", value: AppModel.MainTab.messages) {
                InboxView()
            }
            .badge(chat.unreadTotal)
            Tab("Profile", systemImage: "person.crop.circle", value: AppModel.MainTab.profile) {
                ProfileView()
            }
        }
        // Tapped a chat push → open that WorkStream
        .onChange(of: push.pendingChatID) {
            guard let chatID = push.pendingChatID else { return }
            chat.activeChatID = chatID
            appModel.selectedTab = .messages
            push.pendingChatID = nil
        }
        // Home look: both side windows around Explore; elsewhere only My Orders stays (straight)
        .onChange(of: appModel.selectedTab, initial: true) {
            if appModel.isHome {
                if !appModel.showSidebar { openWindow(id: WindowID.sidebar, value: WindowID.single) }
                if !appModel.showOrders { openWindow(id: WindowID.orders, value: WindowID.single) }
            } else if appModel.showSidebar {
                dismissWindow(id: WindowID.sidebar, value: WindowID.single)
            }
        }
    }
}

// MARK: - Explore tab: search, spotlight carousel, category rows

struct ExploreView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.openWindow) private var openWindow
    @State private var showNotifications = false

    var body: some View {
        CenterStageView()
            .frame(width: 900)
            .padding(.horizontal, 40)
            .padding(.top, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                }
            }
            // Few, clear actions in the standard bottom toolbar ornament
            .toolbar {
                ToolbarItemGroup(placement: .bottomOrnament) {
                    Button {
                        openWindow(id: WindowID.sidebar, value: WindowID.single)
                    } label: {
                        Label("Menu", systemImage: "sidebar.leading")
                    }
                    Button {
                        openWindow(id: WindowID.orders, value: WindowID.single)
                    } label: {
                        Label("My Orders", systemImage: "shippingbox")
                    }
                    ToggleImmersiveSpaceButton()
                    if session.isSignedIn {
                        Button {
                            showNotifications = true
                        } label: {
                            Label(session.unreadNotifications > 0 ? "Alerts (\(session.unreadNotifications))" : "Alerts",
                                  systemImage: session.unreadNotifications > 0 ? "bell.badge.fill" : "bell")
                        }
                    }
                }
            }
            .sheet(isPresented: $showNotifications) { NotificationsView() }
    }
}

/// A side window (Menu / My Orders): keeps AppModel in sync with whether it's open, and on Home tilts its
/// content in toward the viewer, hinged on the edge next to the main window so the outer edge comes forward.
/// The system window bar below stays straight and is how people move or close it.
struct PanelWindow<Content: View>: View {
    enum Kind { case sidebar, orders }
    let kind: Kind
    @ViewBuilder let content: Content
    @Environment(AppModel.self) private var appModel

    /// Left panel hinges on its right edge, right panel on its left edge
    private var yaw: Double { kind == .sidebar ? 34 : -34 }

    var body: some View {
        content
            .rotation3DEffect(.degrees(appModel.isHome ? yaw : 0), axis: (x: 0, y: 1, z: 0),
                              anchor: kind == .sidebar ? .trailing : .leading)
            .offset(z: appModel.isHome ? 24 : 0)
            .animation(.spring(duration: 0.5), value: appModel.isHome)
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

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(GigStore())
        .environment(SessionStore())
        .environment(ChatStore())
        .environment(SellerStore())
        .environment(AppModel())
}
