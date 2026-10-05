import SwiftUI
import AVFoundation
import RealityKit

// MARK: - Sounds: soft chimes for alerts, success and taps (Resources/Sounds)

enum SoundFX: String {
    case alert, success, tap, perch
    /// Soft click for buttons and cards
    case click
    /// Tiny tick as the top carousel moves card to card
    case tick

    @MainActor private static var players: [SoundFX: AVAudioPlayer] = [:]

    /// Plays over other audio and respects the silent switch's "ambient" behaviour
    @MainActor func play() {
        if Self.players.isEmpty {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        }
        if Self.players[self] == nil,
           let url = Bundle.main.url(forResource: rawValue, withExtension: "wav") {
            Self.players[self] = try? AVAudioPlayer(contentsOf: url)
        }
        guard let player = Self.players[self] else { return }
        player.currentTime = 0
        player.play()
    }

    /// The same chime coming from a spot in the room (Showroom)
    @MainActor func play(on entity: Entity) {
        guard let resource = try? AudioFileResource.load(named: "\(rawValue).wav") else { return }
        if entity.components[SpatialAudioComponent.self] == nil {
            entity.components.set(SpatialAudioComponent(gain: -6))
        }
        entity.playAudio(resource)
    }
}

extension View {
    /// Plays a click when this is tapped, without taking the tap away from the button underneath
    func clickSound(_ sound: SoundFX = .click) -> some View {
        simultaneousGesture(TapGesture().onEnded { sound.play() })
    }
}

// MARK: - Live alerts: a new message or order update pops in above the home window

struct LiveAlert: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let title: String
    let body: String
    var chatID: String?
}

private struct LiveAlertsModifier: ViewModifier {
    @Environment(ChatStore.self) private var chat
    @Environment(SessionStore.self) private var session
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow

    /// Unread count per chat at the last check (nil until the first load, so old messages don't alert)
    @State private var lastUnread: [String: Int]?
    @State private var seenNotifications: Set<String>?
    @State private var current: LiveAlert?

    func body(content: Content) -> some View {
        content
            .ornament(visibility: current == nil ? .hidden : .visible,
                      attachmentAnchor: .scene(.top), contentAlignment: .bottom) {
                if let current { card(current) }
            }
            .onChange(of: chat.conversations) { checkChats() }
            .onChange(of: session.notifications) { checkNotifications() }
            .onChange(of: session.uid) {
                lastUnread = nil
                seenNotifications = nil
                current = nil
            }
            // Each alert stays for 6 seconds
            .task(id: current?.id) {
                guard current != nil else { return }
                try? await Task.sleep(for: .seconds(6))
                withAnimation(.spring) { current = nil }
            }
    }

    private func card(_ alert: LiveAlert) -> some View {
        Button {
            open(alert)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: alert.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.brandGreen.gradient, in: Circle())
                    .symbolEffect(.bounce, value: alert.id)
                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.title).font(.headline).lineLimit(1)
                    Text(alert.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                .frame(maxWidth: 420, alignment: .leading)
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassBackgroundEffect(in: Capsule())
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        // Floats a little toward you, in front of the window
        .offset(z: 40)
        .padding(.bottom, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func open(_ alert: LiveAlert) {
        if let chatID = alert.chatID {
            chat.activeChatID = chatID
            appModel.selectedTab = .messages
        } else {
            appModel.ordersPanelShown = true
            appModel.selectedTab = .explore
        }
        withAnimation(.spring) { current = nil }
    }

    private func checkChats() {
        guard let me = session.uid else { return }
        let now = Dictionary(chat.conversations.map { ($0.id, $0.unreadCount(for: me)) }, uniquingKeysWith: max)
        defer { lastUnread = now }
        guard let before = lastUnread else { return }

        // Newest chat that got more unread messages, unless it's the one open on screen
        let fresh = chat.conversations
            .filter { (now[$0.id] ?? 0) > (before[$0.id] ?? 0) }
            .filter { !(appModel.selectedTab == .messages && chat.activeChatID == $0.id) }
            .max { ($0.updatedAt ?? .distantPast) < ($1.updatedAt ?? .distantPast) }
        guard let conversation = fresh else { return }

        let isOrder = conversation.orderId != nil
        show(LiveAlert(icon: isOrder ? "shippingbox.fill" : "bubble.left.fill",
                       title: conversation.title(me: me),
                       body: conversation.lastMessage.isEmpty ? "New message" : conversation.lastMessage,
                       chatID: conversation.id))
    }

    private func checkNotifications() {
        let ids = Set(session.notifications.map(\.id))
        defer { seenNotifications = ids }
        guard let seen = seenNotifications,
              let newest = session.notifications.first(where: { !seen.contains($0.id) && !$0.read }) else { return }
        show(LiveAlert(icon: newest.type == "broadcast" ? "megaphone.fill" : "bell.fill",
                       title: newest.title, body: newest.message))
    }

    private func show(_ alert: LiveAlert) {
        SoundFX.alert.play()
        withAnimation(.spring(duration: 0.5, bounce: 0.35)) { current = alert }
    }
}

extension View {
    /// New messages and order updates appear above this window with a chime
    func liveAlerts() -> some View { modifier(LiveAlertsModifier()) }
}

// MARK: - Confetti: order completed / both reviews in

struct ConfettiBurst: View {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pieces: [Piece] = []
    @State private var start = Date.now

    struct Piece {
        let x: Double, drift: Double, speed: Double, spin: Double, size: Double
        let color: Color
        let isCircle: Bool
    }

    private static let palette: [Color] = [.brandGreen, .yellow, .pink, .orange, .cyan, .white, .purple]
    private static let duration = 2.8

    var body: some View {
        TimelineView(.animation(paused: pieces.isEmpty)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                guard t < Self.duration else { return }
                let fade = max(0, 1 - t / Self.duration)
                for piece in pieces {
                    let y = -20 + piece.speed * t * size.height * 0.45 + 120 * t * t
                    let x = piece.x * size.width + sin(t * 3 + piece.drift) * 40 * piece.drift
                    var c = context
                    c.opacity = fade
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .degrees(piece.spin * t * 360))
                    let rect = CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)
                    c.fill(piece.isCircle ? Path(ellipseIn: rect) : Path(rect), with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) {
            guard !reduceMotion else { return }
            start = .now
            pieces = (0..<140).map { _ in
                Piece(x: .random(in: 0...1), drift: .random(in: -1.5...1.5), speed: .random(in: 0.6...1.4),
                      spin: .random(in: -1.5...1.5), size: .random(in: 10...20),
                      color: Self.palette.randomElement()!, isCircle: .random())
            }
            Task {
                try? await Task.sleep(for: .seconds(Self.duration))
                pieces = []
            }
        }
    }
}

extension View {
    /// Confetti over this window whenever AppModel.celebration ticks
    func celebrations(_ count: Int) -> some View {
        overlay { ConfettiBurst(trigger: count) }
    }
}
