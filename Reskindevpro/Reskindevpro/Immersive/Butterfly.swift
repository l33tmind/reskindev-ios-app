import RealityKit
import RealityKitContent
import Foundation

// MARK: - Showroom butterfly
// Flaps with the model's own animation (metarig_3 in BUTTERFLY.usdz) while it flutters around your room:
// a few hops near other gig cards, lands on your newest saved gig, rests, flutters again,
// then lands on your 2nd most recent gig — and repeats.

/// Which cards to land on, kept current by the Showroom as shelves change (entity names of the cards)
final class ButterflyPerches {
    var names: [String] = []
}

@MainActor
enum Butterfly {
    static let entityName = "butterfly"
    /// Wingspan in metres
    private static let size: Float = 0.12
    /// Flight speed in metres per second
    private static let speed: Float = 0.45
    /// Turn applied on top of "face the direction of travel" in case the model's nose isn't -Z
    static var forwardYaw: Float = 0

    static func load() async -> Entity? {
        guard let butterfly = try? await Entity(named: "BUTTERFLY", in: realityKitContentBundle) else { return nil }
        butterfly.name = entityName
        // Normalise the model to ~12 cm across, whatever units it was exported in
        let extents = butterfly.visualBounds(relativeTo: nil).extents
        let largest = max(extents.x, extents.y, extents.z)
        if largest > 0 { butterfly.scale *= size / largest }
        return butterfly
    }

    /// Plays the wing animation forever; returns the controller so speed can change when resting
    @discardableResult
    static func flap(_ butterfly: Entity) -> AnimationPlaybackController? {
        guard let animation = butterfly.availableAnimations.first(where: { $0.name?.contains("metarig") ?? false })
                ?? butterfly.availableAnimations.first else { return nil }
        return butterfly.playAnimation(animation.repeat(), transitionDuration: 0.2)
    }

    /// The flight loop; runs until the task is cancelled (Showroom closed)
    static func fly(_ butterfly: Entity, in root: Entity, perches: ButterflyPerches) async {
        let wings = flap(butterfly)
        var next = 0
        while !Task.isCancelled {
            // Flutter around neighbouring gigs
            for _ in 0..<3 {
                guard !Task.isCancelled else { return }
                await hop(butterfly, to: wanderPoint(near: root), in: root)
            }
            // Land on the next perch (newest saved gig, then 2nd recent gig, …)
            let names = perches.names.filter { root.findEntity(named: $0) != nil }
            guard !names.isEmpty, let card = root.findEntity(named: names[next % names.count]) else { continue }
            next += 1
            let bounds = card.visualBounds(relativeTo: root)
            let perch = SIMD3<Float>(bounds.center.x, bounds.max.y + 0.005, bounds.center.z)
            await hop(butterfly, to: perch + SIMD3(0, 0.12, 0) + towardViewer(perch) * 0.05, in: root)
            await hop(butterfly, to: perch, in: root, landing: true)
            // Rest with slow wing beats
            wings?.speed = 0.25
            try? await Task.sleep(for: .seconds(4))
            wings?.speed = 1
        }
    }

    // MARK: Moves

    private static func hop(_ butterfly: Entity, to target: SIMD3<Float>, in root: Entity, landing: Bool = false) async {
        let from = butterfly.position(relativeTo: root)
        let distance = simd_distance(from, target)
        guard distance > 0.01 else { return }
        let duration = TimeInterval(max(0.6, distance / (landing ? speed * 0.5 : speed)))

        var transform = butterfly.transform
        transform.translation = target
        transform.rotation = facing(from: from, to: target)
        butterfly.move(to: transform, relativeTo: root, duration: duration, timingFunction: landing ? .easeOut : .easeInOut)
        try? await Task.sleep(for: .seconds(duration))
    }

    /// Yaw toward the direction of travel (level flight)
    private static func facing(from: SIMD3<Float>, to: SIMD3<Float>) -> simd_quatf {
        let d = to - from
        let yaw = atan2(-d.x, -d.z) + forwardYaw
        return simd_quatf(angle: yaw, axis: [0, 1, 0])
    }

    /// A point floating near a random gig card (a little in front of it), or somewhere in front of you
    private static func wanderPoint(near root: Entity) -> SIMD3<Float> {
        let cards = root.children.filter { $0.name.hasPrefix("recent-") || $0.name.hasPrefix("saved-") || $0.name.hasPrefix("top-") }
        guard let card = cards.randomElement() else {
            return [Float.random(in: -0.8...0.8), Float.random(in: 1.1...1.8), Float.random(in: -1.6 ... -0.7)]
        }
        let c = card.visualBounds(relativeTo: root).center
        let jitter = SIMD3<Float>(Float.random(in: -0.35...0.35), Float.random(in: -0.15...0.35), 0)
        return c + jitter + towardViewer(c) * Float.random(in: 0.25...0.6)
    }

    /// Unit vector from a point toward the viewer's standing spot (level)
    private static func towardViewer(_ p: SIMD3<Float>) -> SIMD3<Float> {
        let flat = SIMD3<Float>(-p.x, 0, -p.z)
        let length = simd_length(flat)
        return length > 0 ? flat / length : [0, 0, 1]
    }
}
