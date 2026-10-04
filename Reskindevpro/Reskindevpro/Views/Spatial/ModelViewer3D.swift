import SwiftUI
import RealityKit
import CryptoKit

// MARK: - "View in Your Room": a gig's (or a delivery's) USDZ model in a volume you can set on your desk
// Drag to turn it, pinch with two hands to resize it, Reset puts it back.

struct ModelViewer3D: View {
    let urlString: String

    @Environment(AppModel.self) private var appModel
    @State private var model: Entity?
    @State private var failed = false
    @State private var yaw: Float = 0
    @State private var dragStartYaw: Float = 0
    @State private var scale: Float = 1
    @State private var pinchStartScale: Float = 1

    /// The volume is 0.6 m; the model is fitted into this size and stands on the volume's floor
    private static let fitSize: Float = 0.42
    private static let floorY: Float = -0.28

    var body: some View {
        ZStack {
            RealityView { content in
                let stage = Entity()
                stage.name = "stage"
                stage.position = [0, Self.floorY, 0]
                content.add(stage)
            } update: { content in
                guard let stage = content.entities.first(where: { $0.name == "stage" }) else { return }
                if let model, model.parent == nil { stage.addChild(model) }
                stage.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
                stage.scale = [scale, scale, scale]
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .targetedToAnyEntity()
                    .onChanged { value in
                        yaw = dragStartYaw + Float(value.translation.width) * 0.012
                    }
                    .onEnded { _ in dragStartYaw = yaw }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .targetedToAnyEntity()
                    .onChanged { value in
                        scale = min(max(pinchStartScale * Float(value.magnification), 0.3), 1.4)
                    }
                    .onEnded { _ in pinchStartScale = scale }
            )

            if failed {
                ContentUnavailableView("Couldn't load the 3D model", systemImage: "cube.transparent",
                                       description: Text("Check your connection, or ask the seller for a .usdz file."))
                    .padding(28)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Radius.large))
            } else if model == nil {
                ProgressView("Loading 3D model…")
                    .padding(28)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Radius.large))
            }
        }
        .ornament(attachmentAnchor: .scene(.bottomFront)) {
            HStack(spacing: 14) {
                Label("Drag to turn · pinch to resize", systemImage: "hand.draw")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    withAnimation {
                        yaw = 0; dragStartYaw = 0
                        scale = 1; pinchStartScale = 1
                    }
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassBackgroundEffect(in: Capsule())
        }
        .task(id: urlString) { await load() }
        .onAppear { appModel.openModelURLs.insert(urlString) }
        .onDisappear { appModel.openModelURLs.remove(urlString) }
    }

    private func load() async {
        do {
            let file = try await ModelCache.localFile(for: urlString)
            let entity = try await Entity(contentsOf: file)
            Self.fit(entity)
            // Play the model's own animation if it has one (turntables, rigs)
            if let animation = entity.availableAnimations.first {
                entity.playAnimation(animation.repeat())
            }
            entity.generateCollisionShapes(recursive: true)
            entity.components.set(InputTargetComponent())
            entity.components.set(HoverEffectComponent())
            model = entity
        } catch {
            failed = true
        }
    }

    /// Scale into the volume and stand it on the floor, centred
    private static func fit(_ entity: Entity) {
        let bounds = entity.visualBounds(relativeTo: nil)
        let largest = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        guard largest > 0 else { return }
        let factor = fitSize / largest
        entity.scale *= factor
        let fitted = entity.visualBounds(relativeTo: nil)
        entity.position -= [fitted.center.x, fitted.min.y, fitted.center.z]
    }
}

/// Downloads a remote .usdz once and keeps it in Caches (RealityKit loads models from local files)
enum ModelCache {
    enum CacheError: Error { case badURL }

    static func localFile(for urlString: String) async throws -> URL {
        guard let remote = URL(string: urlString) else { throw CacheError.badURL }
        if remote.isFileURL { return remote }

        let key = SHA256.hash(data: Data(urlString.utf8)).map { String(format: "%02x", $0) }.joined()
        let folder = URL.cachesDirectory.appending(path: "models", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let local = folder.appending(path: "\(key).usdz")
        if FileManager.default.fileExists(atPath: local.path()) { return local }

        let (temp, _) = try await URLSession.shared.download(from: remote)
        try? FileManager.default.removeItem(at: local)
        try FileManager.default.moveItem(at: temp, to: local)
        return local
    }
}
