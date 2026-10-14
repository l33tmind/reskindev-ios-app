import SwiftUI

extension Color {
    /// Reskindev Pro gold
    static let proAmber = Color(red: 245/255, green: 166/255, blue: 35/255)
}

/// Small amber "PRO ⚡" pill shown next to a Reskindev Pro member's name
struct ProBadge: View {
    var size: Size = .regular

    enum Size { case small, regular, large }

    private var font: Font {
        switch size {
        case .small: .system(size: 10, weight: .heavy)
        case .regular: .caption.weight(.heavy)
        case .large: .headline.weight(.heavy)
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill")
            Text("PRO")
        }
        .font(font)
        .foregroundStyle(.black)
        .padding(.horizontal, size == .large ? 10 : 7)
        .padding(.vertical, size == .large ? 4 : 2)
        .background(
            LinearGradient(colors: [Color(red: 1, green: 0.82, blue: 0.35), Color.proAmber],
                           startPoint: .top, endPoint: .bottom),
            in: Capsule()
        )
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reskindev Pro member")
    }
}

/// Badge for someone known only by uid: their users doc is read once and cached
struct ProBadgeFor: View {
    let uid: String?
    var size: ProBadge.Size = .regular

    var body: some View {
        if ProDirectory.shared.isPro(uid) {
            ProBadge(size: size)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ProBadge(size: .small)
        ProBadge()
        ProBadge(size: .large)
    }
    .padding()
}
