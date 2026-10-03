import SwiftUI
import UIKit

// MARK: - Design tokens

extension Color {
    static let brandGreen = Color(red: 16/255, green: 185/255, blue: 129/255)
    static let brandGreenDark = Color(red: 6/255, green: 75/255, blue: 59/255)
    static let starYellow = Color(red: 250/255, green: 190/255, blue: 40/255)
}

/// One corner-radius scale for the whole app
enum Radius {
    static let small: CGFloat = 16
    static let medium: CGFloat = 24
    static let large: CGFloat = 32
}

/// Apple recommends at least 60pt of interactive area for eye + pinch input
enum Hit {
    static let min: CGFloat = 60
}

// MARK: - Gaze hover: element grows and comes forward when you look at it

extension View {
    func gazeLift(scale: CGFloat = 1.05, radius: CGFloat = Radius.large) -> some View {
        self
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: radius))
            .hoverEffect { effect, isActive, _ in
                effect.scaleEffect(isActive ? scale : 1.0)
            }
    }
}

// MARK: - Cached remote image (no flicker while scrolling)

enum ImageCache {
    static let shared: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 200
        return cache
    }()
}

struct CachedImage<Placeholder: View>: View {
    let url: String
    let placeholder: () -> Placeholder
    @State private var image: UIImage?

    init(url: String, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                placeholder()
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let u = URL(string: url) else { image = nil; return }
        if let cached = ImageCache.shared.object(forKey: u as NSURL) {
            image = cached
            return
        }
        image = nil
        guard let result = try? await URLSession.shared.data(from: u),
              let loaded = UIImage(data: result.0) else { return }
        ImageCache.shared.setObject(loaded, forKey: u as NSURL)
        withAnimation(.easeOut(duration: 0.25)) { image = loaded }
    }
}

extension CachedImage where Placeholder == ShimmerBlock {
    init(url: String) {
        self.init(url: url) { ShimmerBlock() }
    }
}

// MARK: - Shimmer / skeleton loading

struct ShimmerBlock: View {
    var cornerRadius: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    init(cornerRadius: CGFloat = 0) {
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.white.opacity(0.08))
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(colors: [.clear, .white.opacity(0.18), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.6)
                            .offset(x: phase * geo.size.width * 1.6)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }
}

/// Placeholder card shown while gigs are loading
struct SkeletonGigCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShimmerBlock(cornerRadius: Radius.small).frame(height: 170)
            HStack(spacing: 8) {
                ShimmerBlock(cornerRadius: 13).frame(width: 26, height: 26)
                ShimmerBlock(cornerRadius: 6).frame(width: 110, height: 12)
            }
            ShimmerBlock(cornerRadius: 6).frame(height: 18)
            ShimmerBlock(cornerRadius: 6).frame(width: 180, height: 18)
            ShimmerBlock(cornerRadius: 6).frame(width: 120, height: 12)
            Spacer()
            HStack {
                ShimmerBlock(cornerRadius: 6).frame(width: 70, height: 14)
                Spacer()
                ShimmerBlock(cornerRadius: 18).frame(width: 110, height: 36)
            }
        }
        .padding(14)
        .frame(width: 300, height: 400)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Radius.large))
        .accessibilityLabel("Loading service")
    }
}

// MARK: - Buttons

struct GlassOutlineButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: Hit.min)
            .background(
                prominent ? AnyShapeStyle(Color.brandGreen) : AnyShapeStyle(Color.white.opacity(configuration.isPressed ? 0.18 : 0.06)),
                in: RoundedRectangle(cornerRadius: Radius.small)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.small)
                    .stroke(Color.white.opacity(prominent ? 0 : 0.7), lineWidth: 1.5)
            )
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: Radius.small))
            .hoverEffect(.highlight)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// Round icon-only button with a proper 60pt hit area and an accessibility label
struct CircleIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3)
                .frame(width: 48, height: 48)
                .background(Color.white.opacity(0.1), in: Circle())
                .frame(width: Hit.min, height: Hit.min)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityLabel(label)
    }
}

// MARK: - Avatar (photo, or first letter on brand gradient)

struct UserAvatar: View {
    let name: String
    let photoUrl: String
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [Color.brandGreen, Color.brandGreenDark], startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay {
                if !photoUrl.isEmpty {
                    CachedImage(url: photoUrl) { initial }
                        .clipShape(Circle())
                } else {
                    initial
                }
            }
    }

    private var initial: some View {
        Text(name.isEmpty ? "r" : String(name.prefix(1)).lowercased())
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(.white)
    }
}

// MARK: - Error alert bound to an optional message

extension View {
    func errorAlert(_ title: String, message: Binding<String?>) -> some View {
        alert(title, isPresented: Binding(get: { message.wrappedValue != nil },
                                          set: { if !$0 { message.wrappedValue = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

// MARK: - Form field on glass

struct GlassField: View {
    let title: String
    @Binding var text: String
    var prompt: String = ""
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            TextField(prompt.isEmpty ? title : prompt, text: $text, axis: axis)
                .textFieldStyle(.plain)
                .lineLimit(axis == .vertical ? 3...8 : 1...1)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.small))
                .overlay(RoundedRectangle(cornerRadius: Radius.small).stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
    }
}

// MARK: - Star rating picker

struct StarRatingPicker: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { star in
                Button { rating = star } label: {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(star <= rating ? Color.starYellow : Color.secondary)
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
                .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
            }
        }
    }
}
