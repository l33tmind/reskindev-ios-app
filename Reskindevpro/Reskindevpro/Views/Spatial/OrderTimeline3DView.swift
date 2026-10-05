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
    /// The stone you tapped; nil = the current step
    @State private var picked: Int?

    private static let labels = ["Payment", "Requirements", "Processing", "Delivered", "Completed"]
    private static let spacing: Float = 0.13
    private static let floorY: Float = -0.27

    private var order: OrderModel? {
        session.order(id: orderID) ?? chat.chatOrders.first { $0.id == orderID }
    }
    private var step: Int { order?.timelineStep ?? 0 }
    private var shown: Int { picked ?? step }

    var body: some View {
        let current = step
        RealityView { content, attachments in
            let stage = Entity()
            stage.name = "stage"
            stage.position = [0, Self.floorY, 0]
            content.add(stage)
            if let panel = attachments.entity(for: "panel") {
                panel.position = [0, 0.4, 0]
                stage.addChild(panel)
            }
        } update: { content, attachments in
            guard let stage = content.entities.first(where: { $0.name == "stage" }) else { return }
            stage.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            Self.build(on: stage, current: current, attachments: attachments, animate: !reduceMotion)
        } attachments: {
            Attachment(id: "panel") { panel }
            // A white tick on every finished stone
            ForEach(Self.labels.indices, id: \.self) { index in
                Attachment(id: "tick-\(index)") {
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(radius: 3)
                        .opacity(index < current || (index == 4 && current == 4) ? 1 : 0)
                        .allowsHitTesting(false)
                }
            }
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
            DragGesture(minimumDistance: 12)
                .targetedToAnyEntity()
                .onChanged { value in yaw = dragStartYaw + Float(value.translation.width) * 0.01 }
                .onEnded { _ in dragStartYaw = yaw }
        )
        // Tap a stone: the panel shows that step (requirements, time left, delivery, review…)
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    if let index = Int(value.entity.name.replacingOccurrences(of: "orb-", with: "")) {
                        withAnimation(.snappy) { picked = (picked == index) ? nil : index }
                    }
                }
        )
        .onAppear { appModel.openOrderTimelineIDs.insert(orderID) }
        .onDisappear { appModel.openOrderTimelineIDs.remove(orderID) }
        .accessibilityLabel("Order progress, step \(current + 1) of 5: \(Self.labels[min(current, 4)])")
    }

    private var panel: some View {
        VStack(spacing: 8) {
            Text(order?.gigTitle ?? "Order").font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.center)
            if let order {
                Text("Order \(order.orderNumber) · \(order.invoiceLabel)").font(.footnote.weight(.semibold).monospaced()).foregroundStyle(.secondary)
                Label(LocalizedStringKey(Self.labels[shown]), systemImage: shown < step || (shown == 4 && step == 4) ? "checkmark.circle.fill" : (shown == step ? "circle.dotted" : "circle"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(shown <= step ? Color.brandGreen : .secondary)
                details(order, step: shown)
                if picked != nil {
                    Button("Back to current step") { withAnimation(.snappy) { picked = nil } }
                        .font(.footnote)
                        .buttonBorderShape(.capsule)
                }
            }
        }
        .frame(maxWidth: 380)
        .padding(.horizontal, 24).padding(.vertical, 14)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    /// What belongs to the step you're looking at
    @ViewBuilder
    private func details(_ order: OrderModel, step i: Int) -> some View {
        switch i {
        case 0:
            VStack(spacing: 4) {
                Text(order.price.usd).font(.system(.title2, design: .rounded).weight(.semibold))
                Text(order.isPendingPayment ? "Payment pending" : "Payment verified")
                    .font(.footnote).foregroundStyle(order.isPendingPayment ? Color.starYellow : Color.brandGreen)
            }
        case 1:
            if order.requirements.isEmpty {
                Text(order.needsRequirements ? "Waiting for the buyer's requirements" : "No requirements yet")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Text(order.requirements).font(.callout).lineLimit(6).multilineTextAlignment(.center)
            }
        case 2:
            VStack(spacing: 6) {
                if order.isTimerRunning {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        let left = order.dueDate.timeIntervalSince(context.date)
                        Label(left < 0 ? "Late by \(OrderCard<EmptyView>.short(-left))" : "Due in \(OrderCard<EmptyView>.short(left))",
                              systemImage: "timer")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(left < 0 ? Color(red: 1, green: 0.4, blue: 0.4) : .primary)
                    }
                } else {
                    Text(step > 2 ? "Work finished" : "Starts after requirements").font(.footnote).foregroundStyle(.secondary)
                }
                if order.status == "revision", !order.revisionNote.isEmpty {
                    Text("Revision: \(order.revisionNote)").font(.footnote).foregroundStyle(.orange).lineLimit(3)
                }
            }
        case 3:
            VStack(spacing: 8) {
                if order.deliveryMessage.isEmpty && order.deliveryLink.isEmpty {
                    Text("Not delivered yet").font(.footnote).foregroundStyle(.secondary)
                } else {
                    if !order.deliveryMessage.isEmpty {
                        Text(order.deliveryMessage).font(.callout).lineLimit(4).multilineTextAlignment(.center)
                    }
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
        default:
            if let review = order.buyerReview {
                VStack(spacing: 4) {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { n in
                            Image(systemName: Double(n) < review.rating ? "star.fill" : "star").foregroundStyle(Color.starYellow)
                        }
                    }
                    if !review.comment.isEmpty { Text("“\(review.comment)”").font(.callout).lineLimit(3) }
                }
            } else {
                Text(order.isCompleted ? "Order complete" : "Not finished yet").font(.footnote).foregroundStyle(.secondary)
            }
        }
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
            if let tick = attachments.entity(for: "tick-\(index)") {
                if tick.parent == nil { stage.addChild(tick) }
                tick.position = [x, 0, 0.05]
            }
        }
    }
}

private struct PulseMarker: Component {}
