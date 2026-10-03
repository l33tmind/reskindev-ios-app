import SwiftUI

// MARK: - Panel A: Left Sidebar
struct LeftSidebarView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ChatStore.self) private var chat
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @State private var showSignIn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile Header
            VStack(spacing: 16) {
                UserAvatar(name: session.displayName, photoUrl: session.photoUrl, size: 90)
                    .shadow(color: Color.brandGreen.opacity(0.5), radius: 16)
                    .accessibilityHidden(true)

                HStack(spacing: 6) {
                    Text(session.isSignedIn ? session.nameOrFallback : "Guest")
                        .font(.title3.bold())
                        .lineLimit(1)
                    if session.isVerified {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue).accessibilityLabel("Verified")
                    }
                }

                if !session.isSignedIn {
                    Button("Sign In") { showSignIn = true }
                        .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                        .padding(.top, 8)
                } else if session.canSell {
                    Button(session.mode == .buyer ? "Switch to Seller" : "Switch to Buyer") {
                        withAnimation { session.mode = session.mode == .buyer ? .seller : .buyer }
                    }
                    .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(28)

            // Menu List (scrolls when a seller has extra items)
            ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                SidebarNavItem(icon: "person", text: session.mode == .seller ? "Manage Orders" : "My Orders",
                               isActive: appModel.showOrders) {
                    openWindow(id: WindowID.orders, value: WindowID.single)
                }
                SidebarNavItem(icon: "tray", text: "Inbox", badge: chat.unreadTotal) {
                    openWindow(id: WindowID.inbox, value: WindowID.single)
                }
                if session.canSell {
                    SidebarNavItem(icon: "square.stack.3d.up", text: "My Gigs") { openProfile(.myGigs) }
                    SidebarNavItem(icon: "dollarsign.circle", text: "Earnings") { openProfile(.earnings) }
                }
                SidebarNavItem(icon: "heart", text: "Saved Services") { openProfile(.saved) }
                SidebarNavItem(icon: "gearshape", text: "Settings") { openProfile(.settings) }
                SidebarNavItem(icon: "questionmark.circle", text: "Help & Policies") {
                    openWindow(id: WindowID.page, value: WindowID.single)
                }
            }
            .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)

            if session.isSignedIn {
                Divider().padding(.horizontal, 28)

                // Delete Account lives in Settings
                SidebarNavItem(icon: "rectangle.portrait.and.arrow.right", text: "Log Out") {
                    session.signOut()
                }
                .padding(16)
            }
        }
        .background(Color.white.opacity(0.03))
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Radius.large))
        .overlay(RoundedRectangle(cornerRadius: Radius.large).stroke(Color.white.opacity(0.18), lineWidth: 1))
        .sheet(isPresented: $showSignIn) { SignInView() }
    }

    private func openProfile(_ tab: AppModel.ProfileTab) {
        appModel.profileTab = tab
        openWindow(id: WindowID.profile, value: WindowID.single)
    }
}

struct SidebarNavItem: View {
    let icon: String
    let text: String
    var isActive: Bool = false
    var isDestructive: Bool = false
    var badge: Int = 0
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isDestructive ? Color.red : (isActive ? Color.white : Color.primary))
                    .frame(width: 28)
                Text(text)
                    .font(.headline)
                Spacer()
                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red, in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: Hit.min)
            .background(
                isActive
                    ? AnyShapeStyle(LinearGradient(colors: [Color.brandGreen.opacity(0.55), Color.brandGreen.opacity(0.25)],
                                                   startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color.clear),
                in: RoundedRectangle(cornerRadius: Radius.small)
            )
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: Radius.small))
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
