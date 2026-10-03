//
//  ImmersiveView.swift
//  Reskindevpro
//
//  Created by Robius Sani on 25/9/26.
//

import SwiftUI
import RealityKit

/// 3D Showroom (mixed immersion): the marketplace's gigs float in an arc around you in your room.
/// Look at a card and pinch to open it; it follows the main window's search and category filter.
struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(GigStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    /// Two rows of six, so it stays readable
    private var gigs: [GigModel] { Array(store.filteredGigs.prefix(12)) }
    private static let titleID = "showroom-title"

    var body: some View {
        RealityView { content, attachments in
            let root = Entity()
            root.name = "showroom"
            content.add(root)
            Self.layout(root: root, gigIDs: gigs.map(\.id), attachments: attachments)
        } update: { content, attachments in
            guard let root = content.entities.first(where: { $0.name == "showroom" }) else { return }
            Self.layout(root: root, gigIDs: gigs.map(\.id), attachments: attachments)
        } attachments: {
            Attachment(id: Self.titleID) { header }
            ForEach(gigs) { gig in
                Attachment(id: gig.id) {
                    Button {
                        openWindow(id: WindowID.gigDetail, value: gig.id)
                    } label: {
                        GigCardView(gig: gig, isFocused: true)
                    }
                    .buttonStyle(.plain)
                    .gazeLift(scale: 1.08)
                    .accessibilityHint("Opens service details")
                }
            }
        }
        .onAppear { appModel.immersiveSpaceState = .open }
        .onDisappear { appModel.immersiveSpaceState = .closed }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("Reskindev Showroom").font(.extraLargeTitle2.weight(.bold))
            Text(store.selectedCategory.map { "\($0) · \(gigs.count) services" } ?? "\(gigs.count) top services around you")
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

    /// Places cards on a 120° arc, 1.7 m away, two rows at eye level, each turned to face you.
    private static func layout(root: Entity, gigIDs: [String], attachments: RealityViewAttachments) {
        // Drop cards that were filtered out
        let wanted = Set(gigIDs + [titleID])
        for child in root.children where !wanted.contains(child.name) {
            child.removeFromParent()
        }

        if let title = attachments.entity(for: titleID) {
            title.name = titleID
            if title.parent == nil { root.addChild(title) }
            title.position = [0, 2.1, -1.9]
            title.scale = [1.4, 1.4, 1.4]
        }

        let radius: Float = 1.7
        let perRow = 6
        let spread: Float = .pi * 2 / 3
        for (index, id) in gigIDs.enumerated() {
            guard let card = attachments.entity(for: id) else { continue }
            card.name = id
            if card.parent == nil { root.addChild(card) }

            let row = index / perRow
            let column = index % perRow
            let countInRow = min(perRow, gigIDs.count - row * perRow)
            let step = countInRow > 1 ? spread / Float(countInRow - 1) : 0
            let angle = countInRow > 1 ? -spread / 2 + step * Float(column) : 0

            card.position = [radius * sin(angle), row == 0 ? 1.55 : 1.0, -radius * cos(angle)]
            card.orientation = simd_quatf(angle: -angle, axis: [0, 1, 0])
            // Window points are small at room distance; make cards ~35 cm wide
            card.scale = [1.6, 1.6, 1.6]
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
        .environment(GigStore())
}
