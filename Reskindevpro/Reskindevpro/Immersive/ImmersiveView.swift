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

    /// One arc of cards
    struct Shelf {
        let key: String
        let title: String
        let icon: String
        let gigs: [GigModel]
    }

    private static let perShelf = 5
    private static let titleID = "showroom-title"

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
            Self.layout(root: root, shelves: shelves, attachments: attachments)
        } update: { content, attachments in
            guard let root = content.entities.first(where: { $0.name == "showroom" }) else { return }
            Self.layout(root: root, shelves: shelves, attachments: attachments)
        } attachments: {
            Attachment(id: Self.titleID) { header }
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
                        .gazeLift(scale: 1.06)
                        .accessibilityHint("Closes the Showroom and opens this service")
                    }
                }
            }
        }
        .onAppear { appModel.immersiveSpaceState = .open }
        .onDisappear { appModel.immersiveSpaceState = .closed }
    }

    /// Leave the Showroom and show just the gig's page
    private func open(_ gig: GigModel) {
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

    /// Each shelf is a 130° arc 2.1 m away, turned to face you; first shelf at eye level, second below
    private static func layout(root: Entity, shelves: [Shelf], attachments: RealityViewAttachments) {
        var wanted: Set<String> = [titleID]
        for shelf in shelves {
            wanted.insert(labelID(shelf))
            shelf.gigs.forEach { wanted.insert(cardID(shelf, $0)) }
        }
        for child in root.children where !wanted.contains(child.name) {
            child.removeFromParent()
        }

        let radius: Float = 2.1
        let spread: Float = .pi * 13 / 18          // 130°
        let shelfHeights: [Float] = [1.6, 0.75]    // card centres (metres from the floor)
        let cardScale: Float = 2.3                  // ≈ 50 cm wide cards

        if let title = attachments.entity(for: titleID) {
            title.name = titleID
            if title.parent == nil { root.addChild(title) }
            title.position = [0, shelves.count > 1 ? 2.55 : 2.4, -radius - 0.2]
            title.scale = [1.6, 1.6, 1.6]
        }

        for (row, shelf) in shelves.prefix(shelfHeights.count).enumerated() {
            let y = shelfHeights[row]
            let count = shelf.gigs.count

            // Shelf label sits at the left end of its arc
            if let label = attachments.entity(for: labelID(shelf)) {
                label.name = labelID(shelf)
                if label.parent == nil { root.addChild(label) }
                let angle = -spread / 2 - 0.22
                label.position = [radius * sin(angle), y + 0.15, -radius * cos(angle)]
                label.orientation = simd_quatf(angle: -angle, axis: [0, 1, 0])
                label.scale = [1.5, 1.5, 1.5]
            }

            for (index, gig) in shelf.gigs.enumerated() {
                guard let card = attachments.entity(for: cardID(shelf, gig)) else { continue }
                card.name = cardID(shelf, gig)
                if card.parent == nil { root.addChild(card) }

                let step = count > 1 ? spread / Float(count - 1) : 0
                let angle = count > 1 ? -spread / 2 + step * Float(index) : 0
                card.position = [radius * sin(angle), y, -radius * cos(angle)]
                card.orientation = simd_quatf(angle: -angle, axis: [0, 1, 0])
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
