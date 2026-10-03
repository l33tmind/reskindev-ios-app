import SwiftUI
import RealityKit

// MARK: - Delivery unbox (volumetric window)
// A gift box spins until you tap it; the lid pops off with sparkles and your latest delivery
// floats out with a button to review it.
struct Delivery3DView: View {
    @Environment(SessionStore.self) private var session
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var isOpened = false

    /// Newest order waiting for the buyer to accept
    private var delivery: OrderModel? {
        session.orders.first { $0.isDelivered && $0.isBuyer(session.uid) }
    }

    var body: some View {
        RealityView { content, attachments in
            let package = Self.makePackage()
            package.position = [0, -0.14, 0]
            content.add(package)
            Self.spin(package)

            if let card = attachments.entity(for: "reveal") {
                card.name = "reveal"
                card.position = [0, 0.06, 0.05]
                card.scale = .zero
                content.add(card)
            }
            if let hint = attachments.entity(for: "hint") {
                hint.name = "hint"
                hint.position = [0, 0.13, 0]
                content.add(hint)
            }
        } update: { content, _ in
            guard isOpened,
                  let package = content.entities.first(where: { $0.name == "package" }),
                  let lid = package.findEntity(named: "lid"),
                  lid.components[OpenedMarker.self] == nil else { return }
            lid.components.set(OpenedMarker())
            Self.open(package: package, lid: lid)
            content.entities.first(where: { $0.name == "hint" })?.isEnabled = false
            if let card = content.entities.first(where: { $0.name == "reveal" }) {
                var to = card.transform
                to.scale = [1, 1, 1]
                to.translation.y = 0.16
                card.move(to: to, relativeTo: card.parent, duration: 0.7, timingFunction: .easeOut)
            }
        } attachments: {
            Attachment(id: "hint") {
                Text("Tap to Unbox")
                    .font(.extraLargeTitle2.weight(.bold))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .glassBackgroundEffect(in: Capsule())
            }
            Attachment(id: "reveal") { revealCard }
        }
        .onAppear { appModel.isDeliveryBoxOpen = true }
        .onDisappear { appModel.isDeliveryBoxOpen = false }
        .gesture(
            TapGesture().targetedToAnyEntity().onEnded { _ in
                guard !isOpened else { return }
                isOpened = true
            }
        )
    }

    private var revealCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "shippingbox.and.arrow.backward.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.brandGreen)
            if let delivery {
                Text("Your delivery is here!").font(.title.weight(.bold))
                Text(delivery.gigTitle).font(.headline).foregroundStyle(.secondary).lineLimit(2)
                    .multilineTextAlignment(.center)
                if !delivery.deliveryMessage.isEmpty {
                    Text(delivery.deliveryMessage).font(.callout).lineLimit(3).multilineTextAlignment(.center)
                }
                Button {
                    appModel.selectedOrderID = delivery.id
                    openWindow(id: WindowID.orders, value: WindowID.single)
                    dismissWindow(id: WindowID.deliveryBox)
                } label: {
                    Label("Review & Accept", systemImage: "checkmark.seal.fill")
                }
                .buttonStyle(GlassOutlineButtonStyle(prominent: true))
            } else {
                Text("All caught up").font(.title.weight(.bold))
                Text("New deliveries from your sellers will appear here.")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Close") { dismissWindow(id: WindowID.deliveryBox) }
                    .buttonStyle(GlassOutlineButtonStyle())
            }
        }
        .padding(28)
        .frame(width: 420)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Radius.large))
    }

    // MARK: Box model (procedural, no asset needed)

    private struct OpenedMarker: Component {}

    private static func makePackage() -> Entity {
        let package = Entity()
        package.name = "package"

        let green = PhysicallyBasedMaterial.make(color: UIColor(Color.brandGreen), roughness: 0.35, metallic: 0.2)
        let ribbon = PhysicallyBasedMaterial.make(color: .white, roughness: 0.25, metallic: 0.0)

        let body = ModelEntity(mesh: .generateBox(size: [0.22, 0.16, 0.22], cornerRadius: 0.012), materials: [green])
        body.name = "body"
        package.addChild(body)
        // Ribbons around the body
        body.addChild(ModelEntity(mesh: .generateBox(size: [0.225, 0.162, 0.03]), materials: [ribbon]))
        body.addChild(ModelEntity(mesh: .generateBox(size: [0.03, 0.162, 0.225]), materials: [ribbon]))

        let lid = ModelEntity(mesh: .generateBox(size: [0.235, 0.035, 0.235], cornerRadius: 0.01), materials: [green])
        lid.name = "lid"
        lid.position = [0, 0.095, 0]
        lid.addChild(ModelEntity(mesh: .generateBox(size: [0.24, 0.037, 0.03]), materials: [ribbon]))
        lid.addChild(ModelEntity(mesh: .generateBox(size: [0.03, 0.037, 0.24]), materials: [ribbon]))
        // Bow
        let bow = ModelEntity(mesh: .generateSphere(radius: 0.025), materials: [ribbon])
        bow.position = [0, 0.03, 0]
        bow.scale = [1.6, 0.7, 1.0]
        lid.addChild(bow)
        package.addChild(lid)

        package.generateCollisionShapes(recursive: true)
        package.components.set(InputTargetComponent())
        package.components.set(HoverEffectComponent())
        return package
    }

    /// Slow turntable spin while closed (the box looks the same every half turn, so it loops seamlessly)
    private static func spin(_ entity: Entity) {
        let animation = FromToByAnimation<Transform>(
            from: Transform(scale: .one, rotation: simd_quatf(angle: 0, axis: [0, 1, 0]), translation: entity.position),
            to: Transform(scale: .one, rotation: simd_quatf(angle: .pi, axis: [0, 1, 0]), translation: entity.position),
            duration: 5,
            timing: .linear,
            bindTarget: .transform,
            repeatMode: .repeat
        )
        if let resource = try? AnimationResource.generate(with: animation) {
            entity.playAnimation(resource)
        }
    }

    private static func open(package: Entity, lid: Entity) {
        package.stopAllAnimations()
        // Lid pops up and tips back
        var lidTo = lid.transform
        lidTo.translation += [0, 0.16, -0.08]
        lidTo.rotation = simd_quatf(angle: -.pi / 3, axis: [1, 0, 0])
        lid.move(to: lidTo, relativeTo: lid.parent, duration: 0.6, timingFunction: .easeOut)

        // Sparkles from the open box
        var sparkles = ParticleEmitterComponent.Presets.magic
        sparkles.emitterShape = .box
        sparkles.emitterShapeSize = [0.2, 0.02, 0.2]
        sparkles.mainEmitter.birthRate = 300
        sparkles.mainEmitter.color = .constant(.single(UIColor(Color.brandGreen)))
        let emitter = Entity()
        emitter.position = [0, 0.1, 0]
        emitter.components.set(sparkles)
        package.addChild(emitter)
    }
}

private extension PhysicallyBasedMaterial {
    static func make(color: UIColor, roughness: Float, metallic: Float) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.roughness = .init(floatLiteral: roughness)
        material.metallic = .init(floatLiteral: metallic)
        return material
    }
}
