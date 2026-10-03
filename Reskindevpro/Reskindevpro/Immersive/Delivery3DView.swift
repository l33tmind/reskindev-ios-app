import SwiftUI
import RealityKit

// MARK: - Delivery AR View (Window Cnt)
struct Delivery3DView: View {
    @State private var isOpened = false
    @Environment(\.dismissWindow) private var dismissWindow
    var body: some View {
        VStack {
            Text(isOpened ? "🎉 Delivery Accepted!" : "Tap to Unbox")
                .font(.extraLargeTitle).padding().glassBackgroundEffect()
            RealityView { content in
                let mesh = MeshResource.generateBox(size: 0.2, cornerRadius: 0.02)
                let material = SimpleMaterial(color: .systemGreen, isMetallic: true)
                let model = ModelEntity(mesh: mesh, materials: [material])
                model.generateCollisionShapes(recursive: false)
                model.components.set(InputTargetComponent())
                content.add(model)
            } update: { content in
                if let model = content.entities.first as? ModelEntity, isOpened {
                    model.model?.materials = [SimpleMaterial(color: .systemBlue, isMetallic: true)]
                    model.transform.scale = [1.2, 1.2, 1.2]
                }
            }
            .gesture(TapGesture().targetedToAnyEntity().onEnded { _ in withAnimation(.spring()) { isOpened.toggle() } })
            if isOpened { Button("Close") { dismissWindow(id: WindowID.deliveryBox) }.buttonStyle(.borderedProminent) }
        }
    }
}
