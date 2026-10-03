import SwiftUI

// Models → Models/       Firestore stores + order/chat writes → Services/
// Colors, radius, CachedImage, skeleton, buttons → DesignSystem/
// Windows: gig detail → Views/GigDetail, orders → Views/Orders (own window, opens beside this one)

// MARK: - Main window: visionOS tab bar (Explore · Messages · Profile)
// The tab bar is the system ornament on the window's leading edge; looking at it expands the labels.
// My Orders lives in its own window next to this one, like a gig detail window.
struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(SessionStore.self) private var session
    @Environment(ChatStore.self) private var chat
    @Environment(\.openWindow) private var openWindow
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
        // Signed-in people get their orders window beside the app
        .onChange(of: session.uid, initial: true) {
            if session.isSignedIn && !appModel.showOrders {
                openWindow(id: WindowID.orders, value: WindowID.single)
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

/// Keeps AppModel in sync with whether the orders window is open (people can close it with the window controls)
struct PanelWindow<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(AppModel.self) private var appModel

    var body: some View {
        content
            .onAppear { appModel.showOrders = true }
            .onDisappear { appModel.showOrders = false }
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
