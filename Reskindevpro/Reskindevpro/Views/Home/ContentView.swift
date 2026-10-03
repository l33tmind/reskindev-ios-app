import SwiftUI

// Models → Models/       Firestore stores + order/chat writes → Services/
// Colors, radius, CachedImage, skeleton, buttons → DesignSystem/
// Windows: gig detail → Views/GigDetail, orders → Views/Orders (own window, opens beside this one)

// MARK: - Main window: visionOS tab bar (Explore · Messages · Profile)
// The tab bar is the system ornament on the window's leading edge; looking at it expands the labels.
// Home (Explore) wears two side panels as ornaments — Menu on the left, My Orders on the right — tilted in
// like a cockpit and attached right beside the window, so the main window bar moves all three together.
// Either panel can be popped out into its own window (with its own window bar) to place it anywhere.
struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(SessionStore.self) private var session
    @Environment(ChatStore.self) private var chat
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
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
        // Closing the main (home) window quits the whole app: take every other window with it,
        // so reopening the app never lands on a lone side panel or gig page
        .onDisappear(perform: closeEverything)
        // Tapped a chat push → open that WorkStream
        .onChange(of: push.pendingChatID) {
            guard let chatID = push.pendingChatID else { return }
            chat.activeChatID = chatID
            appModel.selectedTab = .messages
            push.pendingChatID = nil
        }
    }
}

extension ContentView {
    func closeEverything() {
        if appModel.showOrders { dismissWindow(id: WindowID.orders, value: WindowID.single) }
        if appModel.showSidebar { dismissWindow(id: WindowID.sidebar, value: WindowID.single) }
        if appModel.isPagesOpen { dismissWindow(id: WindowID.page, value: WindowID.single) }
        if appModel.isDeliveryBoxOpen { dismissWindow(id: WindowID.deliveryBox) }
        for gigID in appModel.openGigIDs { dismissWindow(id: WindowID.gigDetail, value: gigID) }
        for key in appModel.openSellerKeys { dismissWindow(id: WindowID.sellerProfile, value: key) }
        if appModel.immersiveSpaceState == .open {
            Task { await dismissImmersiveSpace() }
        }
    }
}

// MARK: - Explore tab: search, spotlight carousel, category rows

struct ExploreView: View {
    @Environment(SessionStore.self) private var session
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @State private var showNotifications = false

    /// Shown as an ornament unless hidden or popped out into its own window
    private var sidebarOrnament: Bool { appModel.sidebarPanelShown && !appModel.showSidebar }
    private var ordersOrnament: Bool { appModel.ordersPanelShown && !appModel.showOrders }

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
            // Cockpit side panels, hugging the window and turned in toward the viewer
            .ornament(visibility: sidebarOrnament ? .visible : .hidden,
                      attachmentAnchor: .scene(.leading), contentAlignment: .trailing) {
                CockpitPanel(side: .left, onPopOut: {
                    openWindow(id: WindowID.sidebar, value: WindowID.single)
                }) {
                    LeftSidebarView().frame(width: 320, height: 720)
                }
                // Leave room for the system tab bar on this edge
                .padding(.trailing, 84)
            }
            .ornament(visibility: ordersOrnament ? .visible : .hidden,
                      attachmentAnchor: .scene(.trailing), contentAlignment: .leading) {
                CockpitPanel(side: .right, onPopOut: {
                    openWindow(id: WindowID.orders, value: WindowID.single)
                }) {
                    RightOrdersView().frame(width: 440, height: 720)
                }
                .padding(.leading, 24)
            }
            // Few, clear actions in the standard bottom toolbar ornament
            .toolbar {
                ToolbarItemGroup(placement: .bottomOrnament) {
                    Button {
                        withAnimation { appModel.sidebarPanelShown.toggle() }
                    } label: {
                        Label(appModel.sidebarPanelShown ? "Hide Menu" : "Show Menu", systemImage: "sidebar.leading")
                    }
                    .disabled(appModel.showSidebar)
                    Button {
                        withAnimation { appModel.ordersPanelShown.toggle() }
                    } label: {
                        Label(appModel.ordersPanelShown ? "Hide Orders" : "Show Orders", systemImage: "shippingbox")
                    }
                    .disabled(appModel.showOrders)
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

/// A popped-out side window (Menu / My Orders): keeps AppModel in sync with whether it's open.
/// While it's open, the matching cockpit ornament hides; closing the window brings the ornament back.

/// Cockpit side panel: turned 34° toward the viewer on the edge next to the window, with a pop-out button
struct CockpitPanel<Content: View>: View {
    enum Side { case left, right }
    let side: Side
    var onPopOut: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 12) {
            content
            Button(action: onPopOut) {
                Label("Open as window", systemImage: "macwindow.on.rectangle")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .help("Move this panel anywhere in your room")
        }
        .rotation3DEffect(.degrees(side == .left ? 34 : -34), axis: (x: 0, y: 1, z: 0),
                          anchor: side == .left ? .trailing : .leading)
    }
}

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

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(GigStore())
        .environment(SessionStore())
        .environment(ChatStore())
        .environment(SellerStore())
        .environment(AppModel())
}
