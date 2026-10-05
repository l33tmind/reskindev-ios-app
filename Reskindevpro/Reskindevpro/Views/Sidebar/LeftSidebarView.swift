import SwiftUI

// MARK: - Panel A: Left Sidebar
struct LeftSidebarView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ChatStore.self) private var chat
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @State private var confirmSwitch = false
    /// Which way the pending switch goes, fixed when the button is tapped so the alert text can't flip while it closes
    @State private var switchingToSeller = true
    @State private var switchingRole = false
    @State private var roleError: String?
    @State private var showSignIn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile Header
            VStack(spacing: 16) {
                Group {
                    if session.isSignedIn {
                        UserAvatar(name: session.displayName, photoUrl: session.photoUrl, size: 90)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 90, height: 90)
                            .background(Color.white.opacity(0.14), in: Circle())
                    }
                }
                .shadow(color: Color.brandGreen.opacity(session.isSignedIn ? 0.5 : 0), radius: 16)
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
                } else if !session.isAdmin {
                    roleSwitchButton.padding(.top, 6)
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
                    appModel.selectedTab = .messages
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
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.large, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
        .sheet(isPresented: $showSignIn) { SignInView() }
        .alert(switchingToSeller ? "Switch to Seller account?" : "Switch to Buyer account?", isPresented: $confirmSwitch) {
            Button("Cancel", role: .cancel) {}
            Button(switchingToSeller ? "Switch to Seller" : "Switch to Buyer") { Task { await switchRole() } }
        } message: {
            Text(switchingToSeller
                 ? "You'll get your seller tools: My Gigs, Earnings and orders on your services. You can switch back any time."
                 : "You'll go back to your buyer profile to order services. Your gigs stay saved. You can switch back any time.")
        }
        .errorAlert("Couldn't switch", message: $roleError)
    }

    private var roleSwitchButton: some View {
        let toSeller = !session.isFreelancer
        return Button {
            switchingToSeller = toSeller
            confirmSwitch = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: toSeller ? "briefcase.fill" : "cart.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.2), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(toSeller ? "Switch to Seller" : "Switch to Buyer").font(.headline)
                    Text(toSeller ? "You're buying now" : "You're selling now")
                        .font(.footnote).opacity(0.85)
                }
                Spacer(minLength: 0)
                if switchingRole { ProgressView() } else { Image(systemName: "arrow.left.arrow.right") }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(Color.brandGreen, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .disabled(switchingRole)
        .accessibilityHint("Asks you to confirm first")
    }

    private func switchRole() async {
        switchingRole = true
        do {
            try await session.switchRole()
            appModel.selectedTab = .explore
        } catch {
            roleError = error.friendlyMessage
        }
        switchingRole = false
    }

    private func openProfile(_ tab: AppModel.ProfileTab) {
        appModel.profileTab = tab
        appModel.selectedTab = .profile
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
                in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
            )
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
