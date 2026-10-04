import SwiftUI
import FirebaseCore

@main
struct ReskindevproApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var gigStore: GigStore
    @State private var session: SessionStore
    @State private var chat: ChatStore
    @State private var seller = SellerStore()
    @State private var appModel = AppModel()

    init() {
        FirebaseApp.configure()
        _gigStore = State(initialValue: GigStore())
        _session = State(initialValue: SessionStore())
        _chat = State(initialValue: ChatStore())
    }

    var body: some Scene {
        // Main window: tab bar (Explore · Messages · Profile)
        WindowGroup(id: WindowID.main) {
            stores(ContentView())
                // Inbox follows the signed-in user
                .onChange(of: session.uid, initial: true) {
                    chat.bind(uid: session.uid, name: session.displayName)
                    seller.bind(uid: session.uid)
                    if session.isSignedIn {
                        PushService.shared.requestPermissionIfNeeded()
                        PushService.shared.saveToken()
                    }
                }
                .onChange(of: session.displayName) { chat.bind(uid: session.uid, name: session.displayName) }
                .onChange(of: session.blockedUsers, initial: true) { chat.blockedByMe = session.blockedUsers }
        }
        .defaultSize(width: 1100, height: 900)
        // The app always opens on the main window, even if another window was the last one open
        .defaultLaunchBehavior(.presented)

        // Menu: its own window on the main window's left (Home look)
        WindowGroup(id: WindowID.sidebar, for: String.self) { _ in
            stores(PanelWindow(kind: .sidebar) { LeftSidebarView().frame(width: 320, height: 720) }.needsHomeWindow())
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultWindowPlacement { _, context in
            if let main = context.windows.first(where: { $0.id == WindowID.main }) {
                return WindowPlacement(.leading(main))
            }
            return WindowPlacement(.none)
        }

        // My Orders / Orders Workspace: its own window, first opened beside the main window
        WindowGroup(id: WindowID.orders, for: String.self) { _ in
            stores(PanelWindow(kind: .orders) { RightOrdersView().frame(width: 440, height: 720) }.needsHomeWindow())
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultWindowPlacement { _, context in
            if let main = context.windows.first(where: { $0.id == WindowID.main }) {
                return WindowPlacement(.trailing(main))
            }
            return WindowPlacement(.none)
        }

        // Gig Detail Window (one per gig)
        WindowGroup(id: WindowID.gigDetail, for: String.self) { $gigID in
            if let gigID {
                stores(GigDetailView(gigID: gigID).needsHomeWindow())
            }
        }
        .windowStyle(.plain)
        .defaultSize(width: 1080, height: 720)
        .restorationBehavior(.disabled)

        // Seller public profile (one per seller)
        WindowGroup(id: WindowID.sellerProfile, for: String.self) { $userKey in
            if let userKey { stores(SellerProfileView(userKey: userKey).needsHomeWindow()) }
        }
        .windowStyle(.plain)
        .defaultSize(width: 1000, height: 760)
        .restorationBehavior(.disabled)

        // Help & Policies (admin-managed pages)
        WindowGroup(id: WindowID.page, for: String.self) { _ in
            stores(PagesView().needsHomeWindow())
        }
        .defaultSize(width: 1000, height: 700)
        .restorationBehavior(.disabled)

        // 3D Showroom: gigs around you in your room
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            stores(ImmersiveView())
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        // 3D Delivery Box Window (Volumetric)
        WindowGroup(id: WindowID.deliveryBox) {
            stores(Delivery3DView().needsHomeWindow())
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.6, height: 0.6, depth: 0.6, in: .meters)
        .restorationBehavior(.disabled)
    }

    /// Every window shares the same live Firestore stores
    private func stores<V: View>(_ view: V) -> some View {
        view
            .environment(gigStore)
            .environment(session)
            .environment(chat)
            .environment(seller)
            .environment(appModel)
            // Idempotent, so any window restored first still gets live data
            .onAppear {
                gigStore.start()
                session.start()
            }
    }
}
