import SwiftUI
import FirebaseCore

@main
struct ReskindevproApp: App {
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
        // Main window: sidebar · 3D carousel · orders + dock ornament
        WindowGroup {
            stores(ContentView())
                // Inbox follows the signed-in user
                .onChange(of: session.uid, initial: true) {
                    chat.bind(uid: session.uid, name: session.displayName)
                    seller.bind(uid: session.uid)
                }
                .onChange(of: session.displayName) { chat.bind(uid: session.uid, name: session.displayName) }
                .onChange(of: session.blockedUsers, initial: true) { chat.blockedByMe = session.blockedUsers }
        }
        .windowStyle(.plain)
        .defaultSize(width: 1900, height: 1000)
        // The app always opens on the main window, even if another window was the last one open
        .defaultLaunchBehavior(.presented)

        // Gig Detail Window (one per gig)
        WindowGroup(id: WindowID.gigDetail, for: String.self) { $gigID in
            if let gigID {
                stores(GigDetailView(gigID: gigID))
            }
        }
        .windowStyle(.plain)
        .defaultSize(width: 1080, height: 720)
        .restorationBehavior(.disabled)

        // Seller public profile (one per seller)
        WindowGroup(id: WindowID.sellerProfile, for: String.self) { $userKey in
            if let userKey { stores(SellerProfileView(userKey: userKey)) }
        }
        .windowStyle(.plain)
        .defaultSize(width: 1000, height: 760)
        .restorationBehavior(.disabled)

        // Help & Policies (admin-managed pages)
        WindowGroup(id: WindowID.page, for: String.self) { _ in
            stores(PagesView())
        }
        .defaultSize(width: 1000, height: 700)
        .restorationBehavior(.disabled)

        // Inbox Window (single, reused)
        WindowGroup(id: WindowID.inbox, for: String.self) { _ in
            stores(InboxView())
        }
        .defaultSize(width: 1100, height: 720)
        .restorationBehavior(.disabled)

        // Profile / Saved / Settings Window (single, reused)
        WindowGroup(id: WindowID.profile, for: String.self) { _ in
            stores(ProfileView())
        }
        .defaultSize(width: 980, height: 680)
        .restorationBehavior(.disabled)

        // 3D Delivery Box Window (Volumetric)
        WindowGroup(id: WindowID.deliveryBox) {
            Delivery3DView()
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
