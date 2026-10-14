import SwiftUI
import StoreKit

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
    @Environment(GigStore.self) private var gigStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.requestReview) private var requestReview
    private let push = PushService.shared
    private let siri = SiriBridge.shared
    @State private var showWelcome = false

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
        #if DEBUG
        // `-GigEditorDemo`: the seller's gig editor as a sheet (layout checks; saving needs a signed-in seller)
        .sheet(isPresented: .constant(ProcessInfo.processInfo.arguments.contains("-GigEditorDemo"))) {
            GigEditorView(gigID: nil)
        }
        // `-ShowroomDemo` launch argument: open the Showroom right away (simulator screenshots)
        // `-OpenGigDemo` / `-DeliveryDemo`: open a gig page / the delivery box once data is in (screenshots)
        .onChange(of: gigStore.isLoading, initial: true) {
            let args = ProcessInfo.processInfo.arguments
            guard !gigStore.isLoading else { return }
            if args.contains("-OpenGigDemo"), let gig = gigStore.spotlightGigs.first {
                openWindow(id: WindowID.gigDetail, value: gig.id)
            }
            if args.contains("-PagesDemo") {
                openWindow(id: WindowID.page, value: WindowID.single)
            }
            if args.contains("-DeliveryDemo") {
                openWindow(id: WindowID.deliveryBox)
            }
            // `-TestOrderGig "<part of a gig title>"`: place an offline-payment order on that gig through
            // the normal checkout code (simulator tests; the visionOS simulator can't be tapped from scripts)
            if let i = args.firstIndex(of: "-TestOrderGig"), i + 1 < args.count {
                Task { await placeTestOrder(titleContains: args[i + 1]) }
            }
            // `-OpenOrderChat <order number without #> [-SendPhotoDemo]`: open that order's chat
            // (and send a small test photo through ChatStore.sendImage, to check the Storage upload)
            if let i = args.firstIndex(of: "-OpenOrderChat"), i + 1 < args.count {
                Task {
                    let number = args[i + 1].uppercased()
                    var found: Conversation?
                    for _ in 0..<40 where found == nil {
                        found = chat.conversations.first { ($0.orderId ?? "").uppercased().hasSuffix(number) }
                        if found == nil { try? await Task.sleep(for: .milliseconds(500)) }
                    }
                    guard let conversation = found else {
                        print("OrderChat: no chat for #\(number) in \(chat.conversations.map { $0.orderId ?? "-" })"); return
                    }
                    chat.activeChatID = conversation.id
                    open(.messages)
                    guard args.contains("-SendPhotoDemo") else { return }
                    try? await Task.sleep(for: .seconds(3))
                    let image = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 400)).image { ctx in
                        UIColor(red: 0.13, green: 0.7, blue: 0.5, alpha: 1).setFill()
                        ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 400))
                        ("Test photo from Vision Pro" as NSString).draw(at: CGPoint(x: 40, y: 170), withAttributes: [
                            .font: UIFont.boldSystemFont(ofSize: 40), .foregroundColor: UIColor.white])
                    }
                    do {
                        try await chat.sendImage(image.jpegData(compressionQuality: 0.8)!)
                        print("OrderChat: photo sent")
                    } catch {
                        print("OrderChat: photo failed \(error)")
                    }
                }
            }
            // `-CheckoutGig "<part of a gig title>"`: open that gig; its page runs the real checkout
            if let i = args.firstIndex(of: "-CheckoutGig"), i + 1 < args.count {
                Task {
                    for _ in 0..<40 where !session.isSignedIn { try? await Task.sleep(for: .milliseconds(500)) }
                    if let gig = gigStore.gigs.first(where: { $0.title.localizedCaseInsensitiveContains(args[i + 1]) }) {
                        print("CheckoutGig: \(gig.title) by \(gig.sellerName)")
                        openWindow(id: WindowID.gigDetail, value: gig.id)
                    } else {
                        print("CheckoutGig: no gig matching \"\(args[i + 1])\"")
                    }
                }
            }
        }
        // `-GuestDemo`: sign in as a guest on launch (the visionOS simulator can't be tapped from scripts)
        .task {
            if ProcessInfo.processInfo.arguments.contains("-GuestDemo"), !session.isSignedIn {
                try? await session.signInAsGuest()
            }
        }
        .task {
            if ProcessInfo.processInfo.arguments.contains("-ShowroomDemo"), appModel.immersiveSpaceState == .closed {
                appModel.immersiveSpaceState = .inTransition
                if case .opened = await openImmersiveSpace(id: appModel.immersiveSpaceID) {} else {
                    appModel.immersiveSpaceState = .closed
                }
            }
        }
        #endif
        .liveAlerts()
        // The 3rd time someone opens the 3D Showroom, ask for an App Store rating (once)
        .onChange(of: appModel.immersiveSpaceState) {
            guard appModel.immersiveSpaceState == .open else { return }
            let key = "showroomVisits"
            let visits = UserDefaults.standard.integer(forKey: key) + 1
            UserDefaults.standard.set(visits, forKey: key)
            guard visits == 3 else { return }
            Task {
                // Let them see the Showroom first
                try? await Task.sleep(for: .seconds(4))
                requestReview()
            }
        }
        // SharePlay: a Watch Together session opens that delivery in the Theater
        .task { await SharePlayCenter.shared.observe() }
        .onChange(of: SharePlayCenter.shared.pendingItem) {
            guard let item = SharePlayCenter.shared.pendingItem else { return }
            SharePlayCenter.shared.pendingItem = nil
            openWindow(id: WindowID.theater, value: item)
        }
        // Widgets: reskindev://orders, reskindev://messages
        .onOpenURL { url in
            guard url.scheme == "reskindev" else { return }
            switch url.host() {
            case "messages": open(.messages)
            default: open(.orders)
            }
        }
        // First launch: a short welcome tour with the butterfly
        .sheet(isPresented: $showWelcome) { WelcomeView() }
        .onAppear { showWelcome = WelcomeView.shouldShow }
        // Closing the main (home) window quits the whole app: take every other window with it,
        // so reopening the app never lands on a lone side panel or gig page
        .onAppear { appModel.isMainOpen = true }
        .onDisappear {
            appModel.isMainOpen = false
            closeEverything()
        }
        // Closing the window sends it to the background before (or instead of) onDisappear
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                appModel.isMainOpen = false
                closeEverything()
            } else if scenePhase == .active {
                appModel.isMainOpen = true
            }
        }
        // Siri: "find video editing on Reskindev" → filter Explore and open the best match
        .onChange(of: siri.pending, initial: true) {
            guard let request = siri.pending, !gigStore.isLoading else { return }
            runSiri(request)
        }
        .onChange(of: gigStore.isLoading) {
            if let request = siri.pending, !gigStore.isLoading { runSiri(request) }
        }
        // Siri: "order a service" → that gig opens with checkout up (it picks up the pending id itself)
        .onChange(of: siri.pendingCheckoutGigID, initial: true) {
            guard let gigID = siri.pendingCheckoutGigID else { return }
            appModel.selectedTab = .explore
            openWindow(id: WindowID.gigDetail, value: gigID)
        }
        // Siri: "show my orders / messages / saved services…"
        .onChange(of: siri.pendingScreen, initial: true) {
            guard let screen = siri.pendingScreen else { return }
            siri.pendingScreen = nil
            open(screen)
        }
        // Tapped a chat push → open that WorkStream
        // `initial` catches a tap that launched the app (the value is set before this view exists);
        // it waits for sign-in, then opens the chat
        .onChange(of: push.pendingChatID, initial: true) { openPendingChat() }
        .onChange(of: session.isSignedIn) { openPendingChat() }
    }
}

extension ContentView {
    fileprivate func openPendingChat() {
        guard let chatID = push.pendingChatID, session.isSignedIn else { return }
        chat.activeChatID = chatID
        appModel.selectedTab = .messages
        push.pendingChatID = nil
    }

    func runSiri(_ request: ServiceSearchRequest) {
        siri.pending = nil
        appModel.selectedTab = .explore
        if let best = gigStore.apply(request) {
            openWindow(id: WindowID.gigDetail, value: best.id)
        }
    }

    func open(_ screen: AppScreen) {
        switch screen {
        case .orders:
            appModel.selectedTab = .explore
            appModel.ordersPanelShown = true
        case .messages:
            appModel.selectedTab = .messages
        case .saved:
            appModel.profileTab = .saved
            appModel.selectedTab = .profile
        case .profile:
            appModel.profileTab = .profile
            appModel.selectedTab = .profile
        case .explore:
            appModel.selectedTab = .explore
        case .showroom:
            guard appModel.immersiveSpaceState == .closed else { return }
            appModel.immersiveSpaceState = .inTransition
            Task {
                if case .opened = await openImmersiveSpace(id: appModel.immersiveSpaceID) {} else {
                    appModel.immersiveSpaceState = .closed
                }
            }
        }
    }

    #if DEBUG
    /// `-TestOrderGig`: one order per gig, as the signed-in person, through OrderService.placeOrder
    fileprivate func placeTestOrder(titleContains fragment: String) async {
        // The guest sign-in (`-GuestDemo`) and the orders listener may still be starting
        for _ in 0..<40 where !session.isSignedIn || session.ordersLoading {
            try? await Task.sleep(for: .milliseconds(500))
        }
        guard let gig = gigStore.gigs.first(where: { $0.title.localizedCaseInsensitiveContains(fragment) }),
              let package = gig.packages.first else {
            print("TestOrder: no gig matching \"\(fragment)\"")
            return
        }
        print("TestOrder: \(gig.title) status=\(gig.status) seller=\(gig.sellerName)")
        guard gig.isVisible else { print("TestOrder: gig is not live yet (needs admin approval)"); return }
        if session.orders.contains(where: { $0.gigId == gig.id }) {
            print("TestOrder: already ordered")
            open(.orders)
            return
        }
        var form = OrderService.CheckoutForm()
        form.phone = "+8801000000000"
        form.requirements = "Test order from a Vision Pro guest. A simple logo with the letter R in green, please."
        let fee = await OrderService.serviceFeePercent()
        do {
            let result = try await OrderService.placeOrder(gig: gig, package: package, form: form,
                                                           pricing: .init(base: package.price, discount: 0, feePercent: fee),
                                                           coupon: nil, session: session)
            print("TestOrder: placed \(result.orderID)")
            open(.orders)
        } catch {
            print("TestOrder: failed \(error)")
        }
    }
    #endif

    func closeEverything() {
        if appModel.showOrders { dismissWindow(id: WindowID.orders, value: WindowID.single) }
        if appModel.showSidebar { dismissWindow(id: WindowID.sidebar, value: WindowID.single) }
        if appModel.isPagesOpen { dismissWindow(id: WindowID.page, value: WindowID.single) }
        if appModel.isDeliveryBoxOpen { dismissWindow(id: WindowID.deliveryBox) }
        for gigID in appModel.openGigIDs { dismissWindow(id: WindowID.gigDetail, value: gigID) }
        for key in appModel.openSellerKeys { dismissWindow(id: WindowID.sellerProfile, value: key) }
        for url in appModel.openModelURLs { dismissWindow(id: WindowID.model3D, value: url) }
        for item in appModel.openTheaters { dismissWindow(id: WindowID.theater, value: item) }
        for id in appModel.openOrderTimelineIDs { dismissWindow(id: WindowID.orderTimeline3D, value: id) }
        if appModel.isEarnings3DOpen { dismissWindow(id: WindowID.earnings3D) }
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
        // Drag the window's corner and everything grows with it (designed for 1100 × 900)
        GeometryReader { geo in
            let scale = min(max(min(geo.size.width / 1100, geo.size.height / 900), 0.8), 2.5)
            CenterStageView()
                .frame(width: 900, height: max(geo.size.height / scale - 24, 400), alignment: .top)
                .padding(.top, 24)
                .scaleEffect(scale, anchor: .top)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
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
                            .labelStyle(.titleAndIcon)
                    }
                    .disabled(appModel.showSidebar)
                    Button {
                        withAnimation { appModel.ordersPanelShown.toggle() }
                    } label: {
                        Label(appModel.ordersPanelShown ? "Hide Orders" : "Show Orders", systemImage: "shippingbox")
                            .labelStyle(.titleAndIcon)
                    }
                    .disabled(appModel.showOrders)
                    ToggleImmersiveSpaceButton()
                    if session.isSignedIn {
                        Button {
                            showNotifications = true
                        } label: {
                            Label(session.unreadNotifications > 0 ? "Alerts (\(session.unreadNotifications))" : "Alerts",
                                  systemImage: session.unreadNotifications > 0 ? "bell.badge.fill" : "bell")
                                .labelStyle(.titleAndIcon)
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
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.black.opacity(0.5))
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
