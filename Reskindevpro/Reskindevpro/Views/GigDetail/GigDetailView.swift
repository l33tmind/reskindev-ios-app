import SwiftUI

/// Opens in its own window: openWindow(id: "GigDetail", value: gig.id)
struct GigDetailView: View {
    let gigID: String
    @Environment(GigStore.self) private var store
    @Environment(AppModel.self) private var appModel
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
        .onAppear { appModel.openGigIDs.insert(gigID) }
        .onDisappear { appModel.openGigIDs.remove(gigID) }
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
    @State private var selectedVideo = 0
    /// Starts on the video when there is one
    @State private var showVideo = true
    @State private var selectedPackageID: String?
    /// One sheet at a time: two sheets on the same view can drop a presentation
    @State private var sheet: GigSheet?

    enum GigSheet: String, Identifiable {
        case signIn, order
        var id: String { rawValue }
    }
    @State private var isContacting = false
    @State private var reviews: [GigReview] = []
    @State private var errorMessage: String?

    private var selectedPackage: GigPackage? {
        gig.packages.first { $0.id == selectedPackageID } ?? gig.packages.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Clear way back to the marketplace (this window opened on top of it)
            HStack(spacing: 8) {
                Button(action: onClose) {
                    Label("Back", systemImage: "chevron.left")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 48)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .accessibilityHint("Closes this service and returns to Explore")
                Spacer()
                CircleIconButton(systemName: session.isSaved(gig.id) ? "heart.fill" : "heart",
                                 label: session.isSaved(gig.id) ? "Remove from saved" : "Save this service") {
                    toggleSave()
                }
                .foregroundStyle(session.isSaved(gig.id) ? Color.red : Color.primary)
            }

        HStack(alignment: .top, spacing: 32) {
            gallery
                .frame(width: 500)

            VStack(spacing: 14) {
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

                // Always visible, whatever you've scrolled to
                if let pkg = selectedPackage { orderBar(pkg) }
            }
        }
        }
        .padding(28)
        .task(id: gig.id) {
            // Siri "Order a service": arrive with checkout already open
            if SiriBridge.shared.pendingCheckoutGigID == gig.id {
                SiriBridge.shared.pendingCheckoutGigID = nil
                sheet = .order
            }
            store.trackView(gig.id)
            store.noteViewed(gig.id)
            reviews = await store.reviews(for: gig.id)
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .signIn:
                SignInView()
            case .order:
                // Signed out: sign in first, then the same sheet turns into checkout
                Group {
                    if session.isSignedIn, let pkg = selectedPackage {
                        CheckoutView(gig: gig, package: pkg)
                    } else {
                        SignInView(onSuccess: {})
                    }
                }
                .animation(.smooth, value: session.isSignedIn)
            }
        }
        .errorAlert("Something went wrong", message: $errorMessage)
    }

    private func toggleSave() {
        guard session.isSignedIn else { sheet = .signIn; return }
        Task {
            do { try await session.toggleSave(gig.id) } catch { errorMessage = error.localizedDescription }
        }
    }

    /// Website ContactSellerButton: open (or create) the general chat and post the gig link
    private func contactSeller() {
        guard session.isSignedIn else { sheet = .signIn; return }
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

    /// Video first when the gig has one (website VideoGallery), photos one tap away
    private var gallery: some View {
        let images = gig.allImages
        let videos = gig.videoIDs
        let playing = showVideo && !videos.isEmpty
        return VStack(alignment: .leading, spacing: 14) {
            if !videos.isEmpty && !images.isEmpty {
                Picker("Media", selection: $showVideo.animation()) {
                    Label("Video", systemImage: "play.rectangle.fill").tag(true)
                    Label("Photos", systemImage: "photo.on.rectangle").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }

            ZStack {
                if playing {
                    YouTubePlayer(videoID: videos[min(selectedVideo, videos.count - 1)])
                } else if images.isEmpty {
                    ShimmerBlock(cornerRadius: Radius.medium)
                } else {
                    CachedImage(url: images[min(selectedImage, images.count - 1)])
                }
            }
            .frame(width: 500, height: 282)
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
            .accessibilityLabel(playing ? "Service video" : "Service image")

            if !gig.model3dUrl.isEmpty {
                Button {
                    openWindow(id: WindowID.model3D, value: gig.model3dUrl)
                } label: {
                    Label("View in Your Room", systemImage: "arkit")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandGreen)
                .frame(width: 500)
                .help("See this seller's work in 3D, right in your space")
            }

            // Thumbnails: more videos, or more photos
            if playing && videos.count > 1 {
                thumbnails(count: videos.count, selected: selectedVideo, label: "Video") { index in
                    CachedImage(url: "https://img.youtube.com/vi/\(videos[index])/mqdefault.jpg")
                        .overlay(Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(.white))
                } select: { selectedVideo = $0 }
            } else if !playing && images.count > 1 {
                thumbnails(count: images.count, selected: selectedImage, label: "Image") { index in
                    CachedImage(url: images[index])
                } select: { selectedImage = $0 }
            }
        }
    }

    private func thumbnails<Thumb: View>(count: Int, selected: Int, label: String,
                                         @ViewBuilder thumb: @escaping (Int) -> Thumb,
                                         select: @escaping (Int) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(0..<count, id: \.self) { index in
                    Button { withAnimation(.easeInOut) { select(index) } } label: {
                        thumb(index)
                            .frame(width: 96, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(index == selected ? Color.brandGreen : .clear, lineWidth: 3)
                            )
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)
                    .accessibilityLabel("\(label) \(index + 1)")
                }
            }
            .padding(4)
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
                    Image(systemName: gig.ratingIcon).foregroundStyle(Color.starYellow)
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
            }
        }
    }

    // MARK: Order bar (pinned under the details)

    private func orderBar(_ pkg: GigPackage) -> some View {
        let isOwnGig = !gig.authorId.isEmpty && gig.authorId == session.uid
        return VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(pkg.name) package").font(.headline)
                    Label("\(pkg.deliveryDays)-day delivery", systemImage: "clock")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text(pkg.price.usd)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.brandGreen)
                    .contentTransition(.numericText())
            }
            if isOwnGig {
                Label("This is your own service.", systemImage: "person.crop.circle")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 12) {
                    Button {
                        sheet = .order
                    } label: {
                        Label("Order Now", systemImage: "cart.fill")
                    }
                    .buttonStyle(GlassOutlineButtonStyle(prominent: true))

                    Button {
                        contactSeller()
                    } label: {
                        if isContacting { ProgressView() } else { Label("Message", systemImage: "message") }
                    }
                    .buttonStyle(GlassOutlineButtonStyle())
                    .frame(width: 170)
                    .disabled(isContacting)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: Radius.medium))
        .animation(.snappy, value: pkg.id)
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
