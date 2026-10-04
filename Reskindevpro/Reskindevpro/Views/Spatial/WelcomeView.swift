import SwiftUI
import RealityKit

/// First-launch tour: the Showroom butterfly flutters above four short pages
struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private static let seenKey = "hasSeenWelcome"
    static var shouldShow: Bool {
        #if DEBUG
        // Screenshot launch options skip the tour
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("Demo") }) { return false }
        #endif
        return !UserDefaults.standard.bool(forKey: seenKey)
    }

    private struct Page {
        let icon: String
        let title: String
        let text: String
    }

    private let pages = [
        Page(icon: "sparkles", title: "Welcome to Reskindev",
             text: "Hire freelancers for apps, video, design and more — and work with them, all around you."),
        Page(icon: "rectangle.3.group", title: "Your space, your layout",
             text: "Menu on the left, My Orders on the right. Hide them from the bottom bar, or pop one out and put it anywhere in your room."),
        Page(icon: "cube.transparent", title: "See it in 3D",
             text: "Open the 3D Showroom to walk among your saved and recent services. Some gigs and deliveries open right on your desk."),
        Page(icon: "bubble.left.and.text.bubble.right", title: "Order, chat, done",
             text: "Every order gets a WorkStream chat with its timeline beside it. Or just ask Siri: \"Find video editing on Reskindev.\""),
    ]

    var body: some View {
        VStack(spacing: 22) {
            ButterflyStage()
                .frame(height: 110)

            let current = pages[page]
            VStack(spacing: 12) {
                Image(systemName: current.icon)
                    .font(.system(size: 34))
                    .foregroundStyle(Color.brandGreen)
                Text(current.title)
                    .font(.extraLargeTitle2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(current.text)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .id(page)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))

            // Page dots
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.brandGreen : Color.white.opacity(0.25))
                        .frame(width: index == page ? 26 : 8, height: 8)
                }
            }
            .accessibilityLabel("Page \(page + 1) of \(pages.count)")

            HStack(spacing: 14) {
                if page < pages.count - 1 {
                    Button("Skip") { finish() }
                        .buttonStyle(.bordered)
                }
                Button {
                    SoundFX.tap.play()
                    if page < pages.count - 1 {
                        withAnimation(.spring) { page += 1 }
                    } else {
                        finish()
                    }
                } label: {
                    Text(page < pages.count - 1 ? "Next" : "Get Started")
                        .font(.headline)
                        .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandGreen)
            }
        }
        .padding(40)
        .frame(width: 680)
        .sheetPresence()
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        dismiss()
    }
}

/// The Showroom butterfly, hovering and flapping in place
private struct ButterflyStage: View {
    @State private var butterfly: Entity?

    var body: some View {
        RealityView { content in
            guard let loaded = await Butterfly.load() else { return }
            // Small and flush with the sheet, so the eye goes to the text, not the butterfly
            loaded.scale *= 0.8
            loaded.position = [0, -0.055, 0]
            loaded.orientation = simd_quatf(angle: .pi / 7, axis: [1, 0, 0])
            content.add(loaded)
            Butterfly.flap(loaded)
            butterfly = loaded
        }
        // Gentle bob up and down until the sheet closes
        .task(id: butterfly == nil) {
            guard let butterfly else { return }
            var up = true
            while !Task.isCancelled {
                var to = butterfly.transform
                to.translation.y += up ? 0.02 : -0.02
                butterfly.move(to: to, relativeTo: butterfly.parent, duration: 1.4, timingFunction: .easeInOut)
                up.toggle()
                try? await Task.sleep(for: .seconds(1.4))
            }
        }
        .accessibilityHidden(true)
    }
}
