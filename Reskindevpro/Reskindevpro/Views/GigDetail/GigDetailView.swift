import SwiftUI

/// Opens in its own window: openWindow(id: "GigDetail", value: gig.id)
struct GigDetailView: View {
    let gigID: String
    @Environment(GigStore.self) private var store
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Group {
            if let gig = store.gig(id: gigID) {
                GigDetailContent(gig: gig) {
                    dismissWindow(id: WindowID.gigDetail, value: gigID)
                }
            } else if store.isLoading {
                ProgressView("Loading service...")
            } else {
                ContentUnavailableView("Service not available",
                                       systemImage: "exclamationmark.magnifyingglass",
                                       description: Text("This gig may have been removed or paused."))
            }
        }
        .frame(minWidth: 1000, minHeight: 680)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Radius.large))
    }
}

private struct GigDetailContent: View {
    let gig: GigModel
    let onClose: () -> Void

    @Environment(SessionStore.self) private var session
    @Environment(ChatStore.self) private var chat
    @Environment(AppModel.self) private var appModel
    @Environment(GigStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @State private var selectedImage = 0
    @State private var selectedPackageID: String?
    @State private var showSignIn = false
    @State private var showCheckout = false
    /// Order Now was pressed while signed out: continue to checkout right after signing in
    @State private var pendingCheckout = false
    @State private var isContacting = false
    @State private var reviews: [GigReview] = []
    @State private var errorMessage: String?

    private var selectedPackage: GigPackage? {
        gig.packages.first { $0.id == selectedPackageID } ?? gig.packages.first
    }

    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            gallery
                .frame(width: 500)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if !gig.packages.isEmpty { packageSection }
                    if !gig.description.isEmpty { aboutSection }
                    if !reviews.isEmpty { GigReviewsSection(reviews: reviews) }
                }
                .padding(.trailing, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .padding(32)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 4) {
                CircleIconButton(systemName: session.isSaved(gig.id) ? "heart.fill" : "heart",
                                 label: session.isSaved(gig.id) ? "Remove from saved" : "Save this service") {
                    toggleSave()
                }
                .foregroundStyle(session.isSaved(gig.id) ? Color.red : Color.primary)
                CircleIconButton(systemName: "xmark", label: "Close", action: onClose)
            }
            .padding(16)
        }
        .task(id: gig.id) {
            store.trackView(gig.id)
            store.noteViewed(gig.id)
            reviews = await store.reviews(for: gig.id)
        }
        .sheet(isPresented: $showSignIn, onDismiss: {
            if pendingCheckout && session.isSignedIn { showCheckout = true }
            pendingCheckout = false
        }) { SignInView() }
        .sheet(isPresented: $showCheckout) {
            if let pkg = selectedPackage {
                CheckoutView(gig: gig, package: pkg)
            }
        }
        .errorAlert("Something went wrong", message: $errorMessage)
    }

    private func toggleSave() {
        guard session.isSignedIn else { showSignIn = true; return }
        Task {
            do { try await session.toggleSave(gig.id) } catch { errorMessage = error.localizedDescription }
        }
    }

    /// Website ContactSellerButton: open (or create) the general chat and post the gig link
    private func contactSeller() {
        guard session.isSignedIn else { showSignIn = true; return }
        isContacting = true
        Task {
            do {
                chat.activeChatID = try await chat.contactSeller(gig: gig)
                appModel.selectedTab = .messages
            } catch {
                errorMessage = error.localizedDescription
            }
            isContacting = false
        }
    }

    // MARK: Gallery

    private var gallery: some View {
        let images = gig.allImages
        return VStack(alignment: .leading, spacing: 14) {
            ZStack {
                if images.isEmpty {
                    ShimmerBlock(cornerRadius: Radius.medium)
                } else {
                    CachedImage(url: images[min(selectedImage, images.count - 1)])
                }
            }
            .frame(width: 500, height: 330)
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
            .accessibilityLabel("Service image")

            if images.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, url in
                            Button { withAnimation(.easeInOut) { selectedImage = index } } label: {
                                CachedImage(url: url)
                                    .frame(width: 96, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(index == selectedImage ? Color.brandGreen : .clear, lineWidth: 3)
                                    )
                            }
                            .buttonStyle(.plain)
                            .hoverEffect(.highlight)
                            .accessibilityLabel("Image \(index + 1)")
                        }
                    }
                    .padding(4)
                }
            }

            if let yt = gig.youtubeUrl, let url = URL(string: yt) {
                Link(destination: url) {
                    Label("Watch video", systemImage: "play.rectangle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: Hit.min)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.small))
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !gig.category.isEmpty {
                Label(gig.category, systemImage: FilterPill.icon(for: gig.category))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brandGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.brandGreen.opacity(0.15), in: Capsule())
            }

            Text(gig.title)
                .font(.largeTitle.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 130) // room for heart + close buttons

            HStack(spacing: 14) {
                // Seller → public profile window (website /user/[id])
                Button {
                    openWindow(id: WindowID.sellerProfile, value: gig.authorId)
                } label: {
                    HStack(spacing: 10) {
                        UserAvatar(name: gig.sellerName, photoUrl: "", size: 36)
                        Text(gig.sellerName.isEmpty ? "Seller" : gig.sellerName)
                            .font(.headline)
                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
                .disabled(gig.authorId.isEmpty)
                .accessibilityHint("Opens the seller's profile")
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").foregroundStyle(Color.starYellow)
                    Text(gig.ratingText).foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
    }

    // MARK: Packages

    private var packageSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Package switcher
            HStack(spacing: 8) {
                ForEach(gig.packages) { pkg in
                    let isOn = pkg.id == selectedPackage?.id
                    Button {
                        withAnimation(.snappy) { selectedPackageID = pkg.id }
                    } label: {
                        Text(pkg.name)
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(isOn ? Color.white : Color.secondary)
                            .background(isOn ? Color.black.opacity(0.5) : Color.clear, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)
                }
            }
            .padding(6)
            .background(Color.white.opacity(0.06), in: Capsule())

            if let pkg = selectedPackage {
                HStack(alignment: .firstTextBaseline) {
                    Text("$\(String(format: "%.0f", pkg.price))")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Color.brandGreen)
                        .contentTransition(.numericText())
                    Spacer()
                    Label("\(pkg.deliveryDays)-day delivery", systemImage: "clock")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                if !pkg.description.isEmpty {
                    Text(pkg.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                let features = gig.features(for: pkg)
                if !features.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(features.enumerated()), id: \.offset) { _, f in
                            Label {
                                Text(f.name).foregroundStyle(f.included ? Color.primary : Color.secondary)
                            } icon: {
                                Image(systemName: f.included ? "checkmark.circle.fill" : "xmark.circle")
                                    .foregroundStyle(f.included ? Color.brandGreen : Color.secondary)
                            }
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: Radius.small))
                }

                let isOwnGig = gig.authorId == session.uid
                VStack(spacing: 12) {
                    Button {
                        if session.isSignedIn { showCheckout = true } else { pendingCheckout = true; showSignIn = true }
                    } label: {
                        Label("Order Now • $\(String(format: "%.0f", pkg.price))", systemImage: "cart.fill")
                    }
                    .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                    .disabled(isOwnGig)

                    Button {
                        contactSeller()
                    } label: {
                        if isContacting { ProgressView() } else { Label("Contact Seller", systemImage: "message") }
                    }
                    .buttonStyle(GlassOutlineButtonStyle())
                    .disabled(isOwnGig || isContacting)

                    if isOwnGig {
                        Label("This is your own service.", systemImage: "person.crop.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About this service")
                .font(.title2.weight(.bold))
            Text(gig.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
