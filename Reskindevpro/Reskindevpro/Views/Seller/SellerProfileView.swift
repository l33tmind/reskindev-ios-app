import SwiftUI
import FirebaseFirestore

/// Public seller profile window (website /user/[id] and reskindev.com/{username})
struct SellerProfileView: View {
    /// uid or username, same as the website route
    let userKey: String

    @Environment(GigStore.self) private var gigStore
    @Environment(SessionStore.self) private var session
    @Environment(ChatStore.self) private var chat
    @Environment(\.openWindow) private var openWindow

    @State private var profile: PublicProfile?
    @State private var uid: String?
    @State private var reviews: [ProfileReview] = []
    @State private var loading = true
    @State private var contacting = false
    @State private var showSignIn = false
    @State private var errorMessage: String?

    /// Marketplace-visible gigs only (admin-approved, not on vacation)
    private var gigs: [GigModel] { gigStore.gigs.filter { $0.authorId == uid } }
    private var sellerReviews: [ProfileReview] { reviews.filter { !$0.isAsBuyer } }
    private var average: Double {
        sellerReviews.isEmpty ? 0 : sellerReviews.map(\.rating).reduce(0, +) / Double(sellerReviews.count)
    }

    var body: some View {
        Group {
            if loading {
                ProgressView()
            } else if let profile, let uid {
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        header(profile, uid: uid)
                        if !gigs.isEmpty { gigsSection }
                        reviewsSection
                    }
                    .padding(40)
                }
            } else {
                ContentUnavailableView("Profile not found", systemImage: "person.crop.circle.badge.questionmark")
            }
        }
        .frame(minWidth: 960, minHeight: 680)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Radius.large))
        .task(id: userKey) { await load() }
        .sheet(isPresented: $showSignIn) { SignInView() }
        .errorAlert("Something went wrong", message: $errorMessage)
    }

    private func header(_ profile: PublicProfile, uid: String) -> some View {
        HStack(alignment: .top, spacing: 28) {
            UserAvatar(name: profile.name, photoUrl: profile.photoUrl, size: 130)
                .overlay(alignment: .bottomTrailing) {
                    Circle().fill(profile.isOnline ? Color.green : Color.gray)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .accessibilityLabel(profile.isOnline ? "Online" : "Offline")
                }
                .shadow(color: Color.brandGreen.opacity(0.5), radius: 20)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text(profile.name).font(.extraLargeTitle2.weight(.bold))
                    if profile.verified {
                        Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(.blue)
                            .accessibilityLabel("Verified")
                    }
                }
                if !profile.username.isEmpty {
                    Text("@\(profile.username)").font(.title3).foregroundStyle(.secondary)
                }
                HStack(spacing: 18) {
                    if !sellerReviews.isEmpty {
                        Label(String(format: "%.1f (%d reviews)", average, sellerReviews.count), systemImage: "star.fill")
                            .foregroundStyle(Color.starYellow)
                    }
                    if !profile.country.isEmpty { Label(profile.country, systemImage: "mappin.and.ellipse") }
                    if let since = profile.memberSince {
                        Label("Member since \(since.formatted(.dateTime.month(.wide).year()))", systemImage: "calendar")
                    }
                }
                .font(.headline)
                Text(profile.bio.isEmpty ? "Welcome to my profile! Here you can find all the premium services and gigs I offer." : profile.bio)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if uid != session.uid {
                    Button {
                        contact(uid: uid, name: profile.name)
                    } label: {
                        if contacting { ProgressView() } else { Label("Contact Me", systemImage: "message") }
                    }
                    .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                    .frame(width: 240)
                    .disabled(contacting)
                }
            }
        }
    }

    private var gigsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(profile?.name.components(separatedBy: " ").first ?? "My")'s Services").font(.title.weight(.bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(gigs) { gig in
                        Button { openWindow(id: WindowID.gigDetail, value: gig.id) } label: { CompactGigCard(gig: gig) }
                            .buttonStyle(.plain)
                            .gazeLift(scale: 1.05, radius: Radius.medium)
                    }
                }
                .padding(6)
            }
        }
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reviews (\(reviews.count))").font(.title.weight(.bold))
            if reviews.isEmpty {
                Text("No reviews yet.").foregroundStyle(.secondary)
            }
            ForEach(reviews) { review in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        UserAvatar(name: review.author, photoUrl: review.authorImage, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(review.author).font(.headline)
                            Text(review.isAsBuyer ? "As Buyer" : "As Seller").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: i < Int(review.rating.rounded()) ? "star.fill" : "star")
                                    .foregroundStyle(Color.starYellow)
                            }
                        }
                        .font(.caption)
                    }
                    if !review.comment.isEmpty { Text(review.comment).foregroundStyle(.secondary) }
                    if let date = review.date {
                        Text(date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: Radius.small))
            }
        }
    }

    // MARK: Data

    private func load() async {
        loading = true
        defer { loading = false }
        let db = Firestore.firestore()
        // uid first, then username (same lookup as the website)
        var snapData: [String: Any]?
        var resolved = userKey
        if let doc = try? await db.collection("users").document(userKey).getDocument(), let d = doc.data() {
            snapData = d
        } else if let q = try? await db.collection("users").whereField("username", isEqualTo: userKey).limit(to: 1).getDocuments(),
                  let doc = q.documents.first {
            snapData = doc.data()
            resolved = doc.documentID
        }
        uid = resolved
        let firstGig = gigStore.gigs.first { $0.authorId == resolved }
        profile = PublicProfile(data: snapData ?? [:], fallbackName: firstGig?.sellerName ?? "Freelancer")

        let revs = (try? await db.collection("users").document(resolved).collection("reviews").getDocuments())?.documents ?? []
        reviews = revs.map { ProfileReview(id: $0.documentID, data: $0.data(), profileUID: resolved) }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    private func contact(uid: String, name: String) {
        guard session.isSignedIn else { showSignIn = true; return }
        contacting = true
        Task {
            do {
                chat.activeChatID = try await chat.contact(userID: uid, name: name)
                openWindow(id: WindowID.inbox, value: WindowID.single)
            } catch {
                errorMessage = error.localizedDescription
            }
            contacting = false
        }
    }
}

private struct PublicProfile {
    let name: String
    let photoUrl: String
    let username: String
    let bio: String
    let country: String
    let verified: Bool
    let isOnline: Bool
    let memberSince: Date?

    init(data d: [String: Any], fallbackName: String) {
        name = FS.string(d["displayName"]) ?? FS.string(d["name"]) ?? fallbackName
        photoUrl = FS.string(d["photoURL"]) ?? FS.string(d["photoUrl"]) ?? ""
        username = d["username"] as? String ?? ""
        bio = d["bio"] as? String ?? ""
        country = d["country"] as? String ?? ""
        verified = d["verified"] as? Bool ?? false
        isOnline = d["isOnline"] as? Bool ?? false
        memberSince = FS.date(d["createdAt"])
    }
}

/// users/{uid}/reviews — written when both sides of an order have reviewed
private struct ProfileReview: Identifiable {
    let id: String
    let author: String
    let authorImage: String
    let rating: Double
    let comment: String
    let date: Date?
    let isAsBuyer: Bool

    init(id: String, data d: [String: Any], profileUID: String) {
        self.id = id
        isAsBuyer = FS.string(d["buyerId"]) == profileUID
        // Reviews of a seller are written by the buyer and vice versa
        author = isAsBuyer
            ? (FS.string(d["freelancerName"]) ?? FS.string(d["userName"]) ?? "Seller")
            : (FS.string(d["buyerName"]) ?? FS.string(d["userName"]) ?? "Client")
        authorImage = isAsBuyer
            ? (FS.string(d["freelancerImage"]) ?? FS.string(d["userImage"]) ?? "")
            : (FS.string(d["buyerImage"]) ?? FS.string(d["userImage"]) ?? "")
        rating = FS.double(d["rating"]) ?? 0
        comment = d["comment"] as? String ?? ""
        date = FS.date(d["createdAt"])
    }
}
