//
//  ImmersiveView.swift
//  Reskindevpro
//
//  Created by Robius Sani on 25/9/26.
//

import SwiftUI
import RealityKit

/// 3D Showroom (mixed immersion): your recently viewed gigs and your saved (♥) gigs float in two arcs
/// around you in your room. Look at a card and pinch: the Showroom closes and that gig's page opens.
struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(GigStore.self) private var store
    @Environment(SessionStore.self) private var session
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var perches = ButterflyPerches()
    @State private var flight: Task<Void, Never>?
    /// Showroom root, so cards can be dragged from SwiftUI
    @State private var showroomRoot: Entity?
    /// A card is being held close to the Save basket
    @State private var overBasket = false

    /// One arc of cards
    struct Shelf {
        let key: String
        let title: String
        let icon: String
        let gigs: [GigModel]
    }

    private static let perShelf = 5
    private static let titleID = "showroom-title"
    private static let basketID = "save-basket"
    /// Beside the Showroom title, above the windows, where it's always in view
    private static let basketPosition: SIMD3<Float> = [0.95, 2.3, -2.2]
    private static let dropDistance: Float = 0.5
    /// Immersive-space points → metres
    private static let metresPerPoint: Float = 1 / 1360

    /// Where a card was when the drag began
    private struct DragOrigin: Component { var position: SIMD3<Float> }

    /// Top arc: recently viewed. Bottom arc: saved. Neither yet → the spotlight picks.
    private var shelves: [Shelf] {
        let recent = store.recentIDs.compactMap { store.gig(id: $0) }.prefix(Self.perShelf)
        let saved = session.savedGigIDs.compactMap { store.gig(id: $0) }.prefix(Self.perShelf)
        var result: [Shelf] = []
        if !recent.isEmpty { result.append(Shelf(key: "recent", title: "Recently Viewed", icon: "clock.arrow.circlepath", gigs: Array(recent))) }
        if !saved.isEmpty { result.append(Shelf(key: "saved", title: "Saved", icon: "heart.fill", gigs: Array(saved))) }
        if result.isEmpty {
            result.append(Shelf(key: "top", title: "Top Services", icon: "sparkles", gigs: store.spotlightGigs))
        }
        return result
    }

    /// Attachment id for a card — the same gig can sit on both shelves
    private static func cardID(_ shelf: Shelf, _ gig: GigModel) -> String { "\(shelf.key)-\(gig.id)" }
    private static func labelID(_ shelf: Shelf) -> String { "label-\(shelf.key)" }

    var body: some View {
        let shelves = self.shelves
        RealityView { content, attachments in
            let root = Entity()
            root.name = "showroom"
            content.add(root)
            showroomRoot = root
            Self.layout(root: root, shelves: shelves, attachments: attachments)
            perches.names = Self.perchNames(shelves)

            // The butterfly starts in front of you and begins its rounds
            if let butterfly = await Butterfly.load() {
                butterfly.position = [0.25, 1.35, -0.9]
                root.addChild(butterfly)
                let perches = perches
                flight = Task { await Butterfly.fly(butterfly, in: root, perches: perches) }
            }
        } update: { content, attachments in
            guard let root = content.entities.first(where: { $0.name == "showroom" }) else { return }
            Self.layout(root: root, shelves: shelves, attachments: attachments)
            perches.names = Self.perchNames(shelves)
        } attachments: {
            Attachment(id: Self.titleID) { header }
            Attachment(id: Self.basketID) { basket }
            ForEach(shelves, id: \.key) { shelf in
                Attachment(id: Self.labelID(shelf)) {
                    Label(shelf.title, systemImage: shelf.icon)
                        .font(.extraLargeTitle2.weight(.bold))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .glassBackgroundEffect(in: Capsule())
                }
                ForEach(shelf.gigs) { gig in
                    Attachment(id: Self.cardID(shelf, gig)) {
                        Button {
                            open(gig)
                        } label: {
                            GigCardView(gig: gig, isFocused: true)
                        }
                        .buttonStyle(.plain)
                        // Gentle lift: these cards are big, and the butterfly may be sitting on top
                        .gazeLift(scale: 1.03)
                        .gesture(dragToSave(cardID: Self.cardID(shelf, gig), gig: gig))
                        .accessibilityHint("Closes the Showroom and opens this service. Drag it to the heart to save it.")
                    }
                }
            }
        }
        .onAppear { appModel.immersiveSpaceState = .open }
        .onDisappear {
            flight?.cancel()
            appModel.immersiveSpaceState = .closed
        }
    }

    /// Where the butterfly lands, in order: newest saved gig, then 2nd most recent gig
    /// (falls back to what's there if one shelf is short)
    private static func perchNames(_ shelves: [Shelf]) -> [String] {
        let saved = shelves.first { $0.key == "saved" }
        let recent = shelves.first { $0.key == "recent" }
        var names: [String] = []
        if let saved, let gig = saved.gigs.first { names.append(cardID(saved, gig)) }
        if let recent, let gig = recent.gigs.dropFirst().first ?? recent.gigs.first { names.append(cardID(recent, gig)) }
        if names.isEmpty, let shelf = shelves.first {
            names = shelf.gigs.prefix(2).map { cardID(shelf, $0) }
        }
        return names
    }

    /// The heart basket: drop a card here to save it
    private var basket: some View {
        VStack(spacing: 8) {
            Image(systemName: overBasket ? "heart.fill" : "heart")
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(overBasket ? .pink : .white)
                .symbolEffect(.bounce, value: overBasket)
            Text(session.isSignedIn ? "Drop a card here to save it" : "Sign in to save services")
                .font(.headline)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Radius.large))
        .scaleEffect(overBasket ? 1.15 : 1)
        .animation(.spring, value: overBasket)
    }

    /// Pick a card up and carry it to the heart; let go anywhere else and it floats back
    private func dragToSave(cardID: String, gig: GigModel) -> some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .immersiveSpace)
            .onChanged { value in
                guard let card = showroomRoot?.findEntity(named: cardID) else { return }
                if card.components[DragOrigin.self] == nil {
                    card.components.set(DragOrigin(position: card.position))
                }
                let origin = card.components[DragOrigin.self]!.position
                let t = value.translation3D
                card.position = origin + SIMD3(Float(t.x), Float(-t.y), Float(t.z)) * Self.metresPerPoint
                overBasket = distance(card.position, Self.basketPosition) < Self.dropDistance
            }
            .onEnded { _ in
                guard let card = showroomRoot?.findEntity(named: cardID),
                      let origin = card.components[DragOrigin.self]?.position else { return }
                card.components.remove(DragOrigin.self)
                let dropped = distance(card.position, Self.basketPosition) < Self.dropDistance
                overBasket = false
                if dropped, session.isSignedIn {
                    SoundFX.success.play(on: card)
                    if !session.isSaved(gig.id) {
                        Task { try? await session.toggleSave(gig.id) }
                    }
                }
                var back = card.transform
                back.translation = origin
                card.move(to: back, relativeTo: card.parent, duration: 0.5, timingFunction: .easeOut)
            }
    }

    /// Leave the Showroom and show just the gig's page
    private func open(_ gig: GigModel) {
        SoundFX.tap.play()
        openWindow(id: WindowID.gigDetail, value: gig.id)
        Task { await dismissImmersiveSpace() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("Reskindev Showroom").font(.extraLargeTitle2.weight(.bold))
            Text("Your recent and saved services, around you")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button {
                Task { await dismissImmersiveSpace() }
            } label: {
                Label("Exit Showroom", systemImage: "xmark")
            }
            .buttonStyle(.bordered)
        }
        .padding(28)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Radius.large))
    }

    /// Each shelf is two arcs 2.1 m away on your left and right (the middle stays clear for the windows),
    /// turned to face you; first shelf at eye level, second below
    private static func layout(root: Entity, shelves: [Shelf], attachments: RealityViewAttachments) {
        var wanted: Set<String> = [titleID, basketID]
        for shelf in shelves {
            wanted.insert(labelID(shelf))
            shelf.gigs.forEach { wanted.insert(cardID(shelf, $0)) }
        }
        for child in root.children where !wanted.contains(child.name) && child.name != Butterfly.entityName {
            child.removeFromParent()
        }

        let radius: Float = 2.1
        let shelfHeights: [Float] = [1.55, 0.8]    // card centres (metres from the floor)
        let cardScale: Float = 2.3                  // ≈ 50 cm wide cards

        if let basket = attachments.entity(for: basketID) {
            basket.name = basketID
            if basket.parent == nil { root.addChild(basket) }
            basket.position = basketPosition
            basket.orientation = simd_quatf(angle: -0.4, axis: [0, 1, 0])
            basket.scale = [1.6, 1.6, 1.6]
        }

        if let title = attachments.entity(for: titleID) {
            title.name = titleID
            if title.parent == nil { root.addChild(title) }
            title.position = [0, shelves.count > 1 ? 2.55 : 2.4, -radius - 0.2]
            title.scale = [1.6, 1.6, 1.6]
        }

        for (row, shelf) in shelves.prefix(shelfHeights.count).enumerated() {
            let y = shelfHeights[row]
            let count = shelf.gigs.count

            // Cards sit to your left and right, leaving the middle clear for the app's windows:
            // ±43°, ±65°, ±87°… alternating left/right
            func angle(_ index: Int) -> Float {
                let side: Float = index.isMultiple(of: 2) ? -1 : 1
                return side * (0.75 + Float(index / 2) * 0.38)
            }

            // Shelf label floats above the first (left) card
            if let label = attachments.entity(for: labelID(shelf)) {
                label.name = labelID(shelf)
                if label.parent == nil { root.addChild(label) }
                let a = angle(0)
                label.position = [radius * sin(a), y + 0.5, -radius * cos(a)]
                label.orientation = simd_quatf(angle: -a, axis: [0, 1, 0])
                label.scale = [1.5, 1.5, 1.5]
            }

            for (index, gig) in shelf.gigs.enumerated() {
                guard let card = attachments.entity(for: cardID(shelf, gig)) else { continue }
                card.name = cardID(shelf, gig)
                if card.parent == nil { root.addChild(card) }

                // Leave a card alone while it's being carried
                guard card.components[DragOrigin.self] == nil else { continue }
                let a = angle(index)
                card.position = [radius * sin(a), y, -radius * cos(a)]
                card.orientation = simd_quatf(angle: -a, axis: [0, 1, 0])
                card.scale = [cardScale, cardScale, cardScale]
            }
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
        .environment(GigStore())
        .environment(SessionStore())
}
