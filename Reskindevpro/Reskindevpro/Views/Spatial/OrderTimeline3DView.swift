import SwiftUI
import RealityKit

/// One order's journey (Payment → Requirements → Processing → Delivered → Completed) as glowing
/// stepping stones floating in your room. Turn it by dragging; the delivered work opens in front of you.
struct OrderTimeline3DView: View {
    let orderID: String
    @Environment(SessionStore.self) private var session
    @Environment(ChatStore.self) private var chat
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var yaw: Float = 0
    @State private var dragStartYaw: Float = 0

    private static let labels = ["Payment", "Requirements", "Processing", "Delivered", "Completed"]
    private static let spacing: Float = 0.13
    private static let floorY: Float = -0.1

    private var order: OrderModel? {
        session.order(id: orderID) ?? chat.chatOrders.first { $0.id == orderID }
    }
    private var step: Int { order?.timelineStep ?? 0 }

    var body: some View {
        let current = step
        RealityView { content, attachments in
            let stage = Entity()
            stage.name = "stage"
            stage.position = [0, Self.floorY, 0]
            content.add(stage)
            if let panel = attachments.entity(for: "panel") {
                panel.position = [0, 0.3, 0]
                stage.addChild(panel)
            }
        } update: { content, attachments in
            guard let stage = content.entities.first(where: { $0.name == "stage" }) else { return }
            stage.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            Self.build(on: stage, current: current, attachments: attachments, animate: !reduceMotion)
        } attachments: {
            Attachment(id: "panel") { panel }
            ForEach(Self.labels.indices, id: \.self) { index in
                Attachment(id: "label-\(index)") {
                    Text(LocalizedStringKey(Self.labels[index]))
                        .font(.subheadline.weight(index == current ? .semibold : .regular))
                        .foregroundStyle(index <= current ? Color.primary : Color.secondary)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .glassBackgroundEffect(in: Capsule())
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .targetedToAnyEntity()
                .onChanged { value in yaw = dragStartYaw + Float(value.translation.width) * 0.01 }
                .onEnded { _ in dragStartYaw = yaw }
        )
        .onAppear { appModel.openOrderTimelineIDs.insert(orderID) }
        .onDisappear { appModel.openOrderTimelineIDs.remove(orderID) }
        .accessibilityLabel("Order progress, step \(current + 1) of 5: \(Self.labels[min(current, 4)])")
    }

    private var panel: some View {
        VStack(spacing: 10) {
            Text(order?.gigTitle ?? "Order").font(.headline).lineLimit(2).multilineTextAlignment(.center)
            if let order {
                Text(order.statusLabel).font(.subheadline).foregroundStyle(.secondary)
                if let item = deliveryItem(order) {
                    Button {
                        if case .model(let url)? = DeliveryContent(link: item.link) {
                            openWindow(id: WindowID.model3D, value: url)
                        } else {
                            openWindow(id: WindowID.theater, value: item)
                        }
                    } label: {
                        Label("View delivery", systemImage: "play.rectangle.fill")
                    }
                    .buttonBorderShape(.capsule)
                    .tint(Color.brandGreen)
                }
            }
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, 24).padding(.vertical, 16)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func deliveryItem(_ order: OrderModel) -> TheaterItem? {
        guard !order.deliveryLink.isEmpty else { return nil }
        return TheaterItem(orderID: order.id, title: order.gigTitle, link: order.deliveryLink, message: order.deliveryMessage)
    }

    /// Stones + connectors; finished ones are green, the current one is bigger and pulses
    private static func build(on stage: Entity, current: Int, attachments: RealityViewAttachments, animate: Bool) {
        let count = labels.count
        let start = -Float(count - 1) * spacing / 2

        for index in 0..<count {
            let x = start + Float(index) * spacing
            let isPassed = index < current, isCurrent = index == current

            let orb: ModelEntity
            if let existing = stage.findEntity(named: "orb-\(index)") as? ModelEntity {
                orb = existing
            } else {
                orb = ModelEntity(mesh: .generateSphere(radius: 0.035), materials: [])
                orb.name = "orb-\(index)"
                orb.position = [x, 0, 0]
                orb.generateCollisionShapes(recursive: false)
                orb.components.set(InputTargetComponent())
                orb.components.set(HoverEffectComponent())
                orb.components.set(GroundingShadowComponent(castsShadow: true))
                stage.addChild(orb)
            }
            var material = PhysicallyBasedMaterial()
            let green = UIColor(Color.brandGreen)
            material.baseColor = .init(tint: (isPassed || isCurrent) ? green : UIColor(white: 0.35, alpha: 1))
            material.emissiveColor = .init(color: green)
            material.emissiveIntensity = isCurrent ? 0.9 : (isPassed ? 0.3 : 0)
            material.roughness = 0.25
            material.metallic = 0.3
            orb.model?.materials = [material]
            orb.scale = SIMD3(repeating: isCurrent ? 1.35 : 1)

            if isCurrent && animate && orb.components[PulseMarker.self] == nil {
                orb.components.set(PulseMarker())
                var up = orb.transform
                up.scale = SIMD3(repeating: 1.55)
                orb.move(to: up, relativeTo: orb.parent, duration: 0.9, timingFunction: .easeInOut)
            }

            if index < count - 1 {
                let name = "link-\(index)"
                let link = (stage.findEntity(named: name) as? ModelEntity) ?? {
                    let e = ModelEntity(mesh: .generateBox(width: spacing - 0.07, height: 0.008, depth: 0.008, cornerRadius: 0.004), materials: [])
                    e.name = name
                    e.position = [x + spacing / 2, 0, 0]
                    stage.addChild(e)
                    return e
                }()
                var m = UnlitMaterial(color: index < current ? green : UIColor(white: 0.4, alpha: 1))
                m.blending = .transparent(opacity: .init(floatLiteral: index < current ? 1 : 0.5))
                link.model?.materials = [m]
            }

            if let label = attachments.entity(for: "label-\(index)") {
                if label.parent == nil { stage.addChild(label) }
                label.position = [x, -0.09, 0.02]
            }
        }
    }
}

private struct PulseMarker: Component {}
