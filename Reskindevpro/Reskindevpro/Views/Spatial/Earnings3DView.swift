import SwiftUI
import RealityKit

private struct BarTarget: Component {
    var height: Float
}

/// Seller earnings, last 6 months, as glowing bars on a little stage you can turn by dragging
struct Earnings3DView: View {
    @Environment(SellerStore.self) private var seller
    @Environment(SessionStore.self) private var session
    @Environment(AppModel.self) private var appModel
    @State private var yaw: Float = 0
    @State private var dragStartYaw: Float = 0

    private static let maxBarHeight: Float = 0.26
    private static let barSize: Float = 0.06
    private static let spacing: Float = 0.09
    private static let floorY: Float = -0.2

    private var months: [(month: Date, amount: Double)] { seller.earnings.monthly }

    var body: some View {
        let months = self.months
        RealityView { content, attachments in
            let stage = Entity()
            stage.name = "stage"
            stage.position = [0, Self.floorY, 0]
            content.add(stage)
            if let title = attachments.entity(for: "title") {
                title.position = [0, 0.42, -0.05]
                stage.addChild(title)
            }
        } update: { content, attachments in
            guard let stage = content.entities.first(where: { $0.name == "stage" }) else { return }
            stage.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            Self.build(on: stage, months: months, attachments: attachments)
        } attachments: {
            Attachment(id: "title") {
                VStack(spacing: 4) {
                    Text("Your Earnings").font(.title.weight(.bold))
                    Text("Last 6 months · \(seller.earnings.totalEarnings.usd) total")
                        .font(.headline).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .glassBackgroundEffect(in: Capsule())
            }
            ForEach(months.indices, id: \.self) { index in
                Attachment(id: "label-\(index)") {
                    VStack(spacing: 2) {
                        Text(months[index].amount.usd).font(.headline.weight(.bold))
                        Text(months[index].month, format: .dateTime.month(.abbreviated))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .targetedToAnyEntity()
                .onChanged { value in yaw = dragStartYaw + Float(value.translation.width) * 0.01 }
                .onEnded { _ in dragStartYaw = yaw }
        )
        .overlay {
            if seller.earningsLoading && months.isEmpty {
                ProgressView("Loading earnings…")
                    .padding(24)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Radius.large))
            }
        }
        .task { await seller.loadEarnings(session: session) }
        .onAppear { appModel.isEarnings3DOpen = true }
        .onDisappear { appModel.isEarnings3DOpen = false }
    }

    /// One bar + label per month; bars grow to their height when the data arrives
    private static func build(on stage: Entity, months: [(month: Date, amount: Double)], attachments: RealityViewAttachments) {
        guard !months.isEmpty else { return }
        let top = max(months.map(\.amount).max() ?? 0, 1)
        let start = -Float(months.count - 1) * spacing / 2

        if stage.findEntity(named: "base") == nil {
            var baseMaterial = PhysicallyBasedMaterial()
            baseMaterial.baseColor = .init(tint: UIColor(white: 0.15, alpha: 1))
            baseMaterial.roughness = 0.4
            let base = ModelEntity(mesh: .generateBox(width: Float(months.count) * spacing + 0.04, height: 0.012,
                                                      depth: barSize + 0.08, cornerRadius: 0.006),
                                   materials: [baseMaterial])
            base.name = "base"
            base.position = [0, -0.006, 0]
            base.generateCollisionShapes(recursive: false)
            base.components.set(InputTargetComponent())
            base.components.set(GroundingShadowComponent(castsShadow: true))
            stage.addChild(base)
        }

        for (index, item) in months.enumerated() {
            let x = start + Float(index) * spacing
            let height = max(Float(item.amount / top) * maxBarHeight, 0.004)
            let name = "bar-\(index)"

            let bar: ModelEntity
            if let existing = stage.findEntity(named: name) as? ModelEntity {
                bar = existing
            } else {
                var material = PhysicallyBasedMaterial()
                let isCurrent = index == months.count - 1
                material.baseColor = .init(tint: UIColor(Color.brandGreen).withAlphaComponent(isCurrent ? 1 : 0.75))
                material.emissiveColor = .init(color: UIColor(Color.brandGreen))
                material.emissiveIntensity = isCurrent ? 0.6 : 0.2
                material.roughness = 0.25
                material.metallic = 0.3
                // Unit-height box, scaled on Y so the height can animate
                bar = ModelEntity(mesh: .generateBox(width: barSize, height: 1, depth: barSize, cornerRadius: 0.006),
                                  materials: [material])
                bar.name = name
                bar.scale = [1, 0.001, 1]
                bar.position = [x, 0, 0]
                bar.generateCollisionShapes(recursive: false)
                bar.components.set(InputTargetComponent())
                bar.components.set(HoverEffectComponent())
                bar.components.set(GroundingShadowComponent(castsShadow: true))
                stage.addChild(bar)
            }
            // Animate only when the target changes (updates also run while you turn the stage)
            if bar.components[BarTarget.self]?.height != height {
                bar.components.set(BarTarget(height: height))
                var to = bar.transform
                to.scale = [1, height, 1]
                to.translation = [x, height / 2, 0]
                bar.move(to: to, relativeTo: stage, duration: 0.9, timingFunction: .easeOut)
            }

            if let label = attachments.entity(for: "label-\(index)") {
                if label.parent == nil { stage.addChild(label) }
                label.position = [x, height + 0.05, barSize / 2 + 0.01]
            }
        }
    }
}
