import SwiftUI

struct GigCardView: View {
    let gig: GigModel
    var isFocused: Bool = false

    /// Video still first, else the second photo
    private var previewImage: (url: String, isVideo: Bool)? {
        if let id = gig.videoIDs.first { return ("https://img.youtube.com/vi/\(id)/hqdefault.jpg", true) }
        if gig.allImages.count > 1 { return (gig.allImages[1], false) }
        return nil
    }

    @ViewBuilder
    private var lookPreview: some View {
        if let preview = previewImage {
            CachedImage(url: preview.url)
                .frame(height: 170)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Radius.small))
                .overlay(alignment: .bottomLeading) {
                    Label(preview.isVideo ? "Video" : "More photos",
                          systemImage: preview.isVideo ? "play.circle.fill" : "photo.on.rectangle")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.6), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(10)
                }
                .allowsHitTesting(false)
                .hoverEffect { effect, isActive, _ in
                    effect.opacity(isActive ? 1 : 0)
                }
                .accessibilityHidden(true)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover image (inset, rounded)
            CachedImage(url: gig.imageUrl)
                .frame(height: 170)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Radius.small))
                // Look at the card: the gig's video frame (or its next photo) fades in as a preview
                .overlay { lookPreview }
                .overlay(alignment: .topLeading) {
                    if gig.isFeatured {
                        Label("Featured", systemImage: "star.fill")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.starYellow, in: Capsule())
                            .foregroundStyle(.black)
                            .padding(10)
                    }
                }
                .padding(12)

            VStack(alignment: .leading, spacing: 10) {
                // Seller
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.brandGreen.opacity(0.35))
                        .frame(width: 26, height: 26)
                        .overlay(
                            Text(String(gig.sellerName.prefix(1)).uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        )
                    Text(gig.sellerName.isEmpty ? "Seller" : gig.sellerName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Title
                Text(gig.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2, reservesSpace: true)

                // Rating
                HStack(spacing: 4) {
                    Image(systemName: gig.ratingIcon).foregroundStyle(Color.starYellow)
                    Text(gig.ratingText).foregroundStyle(.secondary)
                }
                .font(.subheadline)

                Spacer(minLength: 6)

                // Footer: category + price pill
                HStack {
                    Text(gig.category)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("FROM").font(.caption2.weight(.semibold))
                        Text("$\(String(format: "%.0f", gig.price))").font(.title3.weight(.bold))
                    }
                    // Solid pill: green-on-green glass was hard to read in bright rooms
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.brandGreen, in: Capsule())
                    .shadow(color: Color.brandGreen.opacity(isFocused ? 0.6 : 0), radius: 12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            // Side cards in the carousel are mostly hidden behind the focused one: fade their text so it doesn't clash
            .opacity(isFocused ? 1 : 0.35)
        }
        .frame(width: 300, height: 400)
        .background(Color.white.opacity(isFocused ? 0.16 : 0.04))
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.large)
                .stroke(Color.white.opacity(isFocused ? 0.35 : 0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Smaller card used in the rows under the carousel:
/// picture, seller, a two-line title, then rating and price on one line
struct CompactGigCard: View {
    let gig: GigModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CachedImage(url: gig.imageUrl)
                .frame(height: 110)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.brandGreen.opacity(0.35))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Text(String(gig.sellerName.prefix(1)).uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    )
                Text(gig.sellerName.isEmpty ? "Seller" : gig.sellerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Always two lines tall, so every card in a row lines up
            Text(gig.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: gig.ratingIcon).foregroundStyle(Color.starYellow)
                Text(gig.ratingShort).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 6)
                Text("$\(String(format: "%.0f", gig.price))")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.brandGreen)
            }
            .font(.caption)
        }
        .padding(10)
        .frame(width: 210, height: 250)
        .background(Color.white.opacity(0.06))
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.white.opacity(0.14), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

struct FilterPill: View {
    let title: String
    let icon: String
    let isActive: Bool
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.subheadline.weight(.semibold))
                Text(title).font(.callout.weight(.medium))
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 52)
            .foregroundStyle(.white)
            .background(isActive ? Color.black.opacity(0.55) : Color.white.opacity(0.06), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(isActive ? 0 : 0.15), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    /// Picks an SF Symbol from the category name coming from Firestore
    static func icon(for category: String) -> String {
        let c = category.lowercased()
        if c.contains("video") || c.contains("edit") { return "film" }
        if c.contains("mobile") || c.contains("app") || c.contains("ios") || c.contains("android") { return "iphone" }
        if c.contains("web") || c.contains("site") { return "globe" }
        if c.contains("market") || c.contains("seo") || c.contains("social") { return "megaphone.fill" }
        if c.contains("design") || c.contains("logo") || c.contains("ui") { return "paintbrush.pointed.fill" }
        if c.contains("writ") || c.contains("content") { return "pencil.line" }
        if c.contains("music") || c.contains("audio") { return "music.note" }
        return "sparkles"
    }
}
