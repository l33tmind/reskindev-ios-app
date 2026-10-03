import SwiftUI

/// Profile window: Profile · Saved Services · Settings (website /profile, /profile/saved, /profile/settings)
struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var showSignIn = false

    var body: some View {
        @Bindable var appModel = appModel

        Group {
            if session.isSignedIn {
                NavigationSplitView {
                    List(AppModel.ProfileTab.allCases.filter { session.canSell || !$0.sellerOnly },
                         selection: Binding($appModel.profileTab)) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                    .navigationTitle("Account")
                } detail: {
                    switch appModel.profileTab {
                    case .profile: ProfileOverview()
                    case .saved: SavedServicesView()
                    case .settings: ProfileSettingsView()
                    case .myGigs: MyGigsView()
                    case .earnings: EarningsView()
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("Sign in to see your profile", systemImage: "person.crop.circle")
                } actions: {
                    Button("Sign In") { showSignIn = true }
                        .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                        .frame(width: 220)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .sheet(isPresented: $showSignIn) { SignInView() }
    }
}

// MARK: - Overview

private struct ProfileOverview: View {
    @Environment(SessionStore.self) private var session

    private var completedCount: Int { session.orders.filter(\.isCompleted).count }
    private var activeCount: Int { session.orders.filter { !$0.isCompleted && $0.status != "cancelled" }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 24) {
                    UserAvatar(name: session.displayName, photoUrl: session.photoUrl, size: 110)
                        .shadow(color: Color.brandGreen.opacity(0.5), radius: 18)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.nameOrFallback).font(.extraLargeTitle2.weight(.bold))
                        if !session.username.isEmpty {
                            Text("@\(session.username)").font(.title3).foregroundStyle(.secondary)
                        }
                        Text((session.role ?? "buyer").capitalized)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.brandGreen)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.brandGreen.opacity(0.15), in: Capsule())
                    }
                }

                HStack(spacing: 16) {
                    StatTile(title: "Wallet Balance", value: session.walletBalance.usd, icon: "wallet.bifold")
                    StatTile(title: "Active Orders", value: "\(activeCount)", icon: "clock")
                    StatTile(title: "Completed", value: "\(completedCount)", icon: "checkmark.seal")
                    StatTile(title: "Saved", value: "\(session.savedGigIDs.count)", icon: "heart")
                }

                VStack(alignment: .leading, spacing: 14) {
                    if !session.email.isEmpty { Label(session.email, systemImage: "envelope") }
                    if !session.phone.isEmpty { Label(session.phone, systemImage: "phone") }
                    if !session.country.isEmpty { Label(session.country, systemImage: "mappin.and.ellipse") }
                    if let since = session.memberSince {
                        Label("Joined \(since.formatted(.dateTime.month(.wide).year()))", systemImage: "calendar")
                    }
                }
                .font(.title3)

                if !session.bio.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About").font(.title2.weight(.bold))
                        Text(session.bio).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(36)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Profile")
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(Color.brandGreen)
            Text(value).font(.title.weight(.bold)).lineLimit(1).minimumScaleFactor(0.6)
            Text(title).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: Radius.medium))
    }
}

// MARK: - Saved services (users/{uid}.savedGigs)

private struct SavedServicesView: View {
    @Environment(SessionStore.self) private var session
    @Environment(GigStore.self) private var gigStore
    @Environment(\.openWindow) private var openWindow

    private var savedGigs: [GigModel] {
        session.savedGigIDs.compactMap { gigStore.gig(id: $0) }
    }

    var body: some View {
        Group {
            if savedGigs.isEmpty {
                ContentUnavailableView("No saved services", systemImage: "heart",
                                       description: Text("Tap the heart on a service to save it here."))
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 18)], spacing: 18) {
                        ForEach(savedGigs) { gig in
                            Button {
                                openWindow(id: WindowID.gigDetail, value: gig.id)
                            } label: {
                                CompactGigCard(gig: gig)
                            }
                            .buttonStyle(.plain)
                            .gazeLift(scale: 1.05, radius: Radius.medium)
                        }
                    }
                    .padding(28)
                }
            }
        }
        .navigationTitle("Saved Services")
    }
}

// MARK: - Settings (same fields + username check as the website)

private struct ProfileSettingsView: View {
    @Environment(SessionStore.self) private var session
    @State private var displayName = ""
    @State private var username = ""
    @State private var phone = ""
    @State private var country = ""
    @State private var bio = ""
    @State private var isSaving = false
    @State private var saved = false
    @State private var errorMessage: String?
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GlassField(title: "Display name", text: $displayName)
                GlassField(title: "Username", text: $username)
                GlassField(title: "Phone", text: $phone)
                GlassField(title: "Country", text: $country)
                GlassField(title: "Bio", text: $bio, axis: .vertical)

                HStack {
                    if saved {
                        Label("Profile updated successfully!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.brandGreen)
                    }
                    Spacer()
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView() } else { Text("Save Changes") }
                    }
                    .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                    .frame(width: 240)
                    .disabled(isSaving || displayName.trimmed.isEmpty)
                }

                Divider().padding(.vertical, 12)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Danger Zone").font(.headline).foregroundStyle(.red)
                    Text("Deleting your account removes your login. Orders and chats stay on record for the other side.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("Delete Account", role: .destructive) { confirmDelete = true }
                        .buttonStyle(.bordered)
                }
            }
            .padding(36)
        }
        .navigationTitle("Settings")
        .onAppear(perform: load)
        .errorAlert("Something went wrong", message: $errorMessage)
        .confirmationDialog("Delete your account?", isPresented: $confirmDelete) {
            Button("Delete Account", role: .destructive) {
                Task {
                    do { try await session.deleteAccount() } catch { errorMessage = error.localizedDescription }
                }
            }
        } message: {
            Text("This permanently removes your Reskindev account.")
        }
    }

    private func load() {
        displayName = session.displayName
        username = session.username
        phone = session.phone
        country = session.country
        bio = session.bio
    }

    private func save() async {
        isSaving = true
        saved = false
        do {
            try await session.updateProfile(displayName: displayName, username: username,
                                            phone: phone, country: country, bio: bio)
            saved = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
