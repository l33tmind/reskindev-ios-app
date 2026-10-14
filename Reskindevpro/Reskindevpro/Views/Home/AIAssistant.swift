import SwiftUI

struct AIAssistantSection: View {
    let gigs: [GigModel]
    let searchText: String
    let resultCount: Int
    var onSelect: (GigModel) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floatingOffset: CGFloat = 0

    private var message: String {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return "Hi! Here are today's top services.\nLook at a card and pinch to open it." }
        if resultCount == 0 { return "No matches for “\(q)” yet.\nTry another keyword." }
        return "Found \(resultCount) services for “\(q)”!\nHere are the best matches..."
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 28) {

            // Orb and speech bubble
            VStack(spacing: 18) {
                Text(message)
                    .font(.callout.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Radius.medium))
                    .contentTransition(.opacity)
                    .animation(.easeInOut, value: message)

                AssistantOrb()
                    .offset(y: floatingOffset)
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                            floatingOffset = -12
                        }
                    }
                    .accessibilityLabel("Reskindev assistant")
            }

            // Mini results (real gigs)
            if !gigs.isEmpty {
                VStack(spacing: 8) {
                    ForEach(gigs) { gig in
                        Button { onSelect(gig) } label: {
                            AIMiniResultCard(gig: gig)
                        }
                        .buttonStyle(.plain)
                        .gazeLift(scale: 1.03, radius: Radius.small)
                    }
                }
                .padding(10)
                .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Radius.medium))
            }
        }
    }
}

struct AssistantOrb: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color.brandGreen, Color.brandGreenDark],
                                     center: .init(x: 0.4, y: 0.35), startRadius: 4, endRadius: 70))
            // glossy highlight
            Circle()
                .fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center))
                .padding(8)

            // Face
            VStack(spacing: 8) {
                HStack(spacing: 22) {
                    Capsule().fill(.white).frame(width: 14, height: 18)
                    Capsule().fill(.white).frame(width: 14, height: 18)
                }
                .shadow(color: .white.opacity(0.9), radius: 6)
                Circle()
                    .trim(from: 0.12, to: 0.38)
                    .stroke(.white, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .frame(width: 30, height: 30)
                    .offset(y: -18)
            }
            .offset(y: 8)
        }
        .frame(width: 110, height: 110)
        .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 2))
        .shadow(color: Color.brandGreen.opacity(0.9), radius: 40)
    }
}

struct AIMiniResultCard: View {
    let gig: GigModel

    var body: some View {
        HStack(spacing: 12) {
            CachedImage(url: gig.imageUrl)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(gig.title).font(.subheadline.weight(.bold)).lineLimit(1)
                Text(gig.sellerName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 3) {
                    Image(systemName: gig.ratingIcon).foregroundStyle(Color.starYellow)
                    Text(gig.ratingText).foregroundStyle(.secondary)
                }
                .font(.caption2)
            }
            Spacer(minLength: 8)
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.brandGreen.opacity(0.6), in: Circle())
        }
        .padding(12)
        .frame(width: 310)
        .frame(minHeight: Hit.min)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: Radius.small))
        .accessibilityElement(children: .combine)
    }
}
