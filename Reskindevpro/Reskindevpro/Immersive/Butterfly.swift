import RealityKit
import RealityKitContent
import Foundation

// MARK: - Showroom butterfly
// Three wing animations from butterfly.glb (flap, fly, glide) while it flutters around your room:
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

    /// The three wing animations from butterfly.glb (one per file, same skeleton)
    enum Clip: CaseIterable {
        /// metarig|3: wings open and close in place (resting)
        case flap
        /// metarig|!: the fast flying wing beat, root motion removed so we steer it
        case fly
        /// metarig|2: wings spread, gliding
        case glide

        var file: String {
            switch self {
            case .flap: "BUTTERFLY"
            case .fly: "ButterflyFly"
            case .glide: "ButterflyGlide"
            }
        }
    }

    private static var clips: [Clip: AnimationResource] = [:]

    /// The model's width in its own units while animating (measured in Blender). RealityKit's bounds can't be
    /// used: the skeleton's rest pose is scattered and only comes together once an animation plays.
    private static let modelUnitsAcross: Float = 100
    /// Centre of the animated body in model units (Y-up), so the container's origin sits in the middle of it
    private static let modelCentre: SIMD3<Float> = [-5, 47, -4]

    static func load() async -> Entity? {
        guard let model = try? await Entity(named: Clip.flap.file, in: realityKitContentBundle) else { return nil }
        model.name = "model"
        let factor = size / modelUnitsAcross
        model.scale = [factor, factor, factor]
        model.position = -modelCentre * factor

        // Everything else moves, turns and shadows the container
        let butterfly = Entity()
        butterfly.name = entityName
        butterfly.addChild(model)
        // A soft shadow on the cards, desk and floor below, so it sits in the real room
        butterfly.components.set(GroundingShadowComponent(castsShadow: true))

        // Wing animations, borrowed from the other two files
        if clips.isEmpty {
            clips[.flap] = model.availableAnimations.first
            for clip in [Clip.fly, .glide] {
                if let source = try? await Entity(named: clip.file, in: realityKitContentBundle) {
                    clips[clip] = source.availableAnimations.first
                }
            }
        }
        return butterfly
    }

    /// Switches the wings to a clip, looping, with a short blend; falls back to the resting flap
    @discardableResult
    static func play(_ clip: Clip, on butterfly: Entity, speed: Float = 1) -> AnimationPlaybackController? {
        let model = butterfly.findEntity(named: "model") ?? butterfly
        guard let animation = clips[clip] ?? clips[.flap] ?? model.availableAnimations.first else { return nil }
        let controller = model.playAnimation(animation.repeat(), transitionDuration: 0.25, startsPaused: false)
        controller.speed = speed
        return controller
    }

    /// Plays the resting wing animation forever (Welcome screen)
    @discardableResult
    static func flap(_ butterfly: Entity) -> AnimationPlaybackController? {
        play(.flap, on: butterfly)
    }

    /// Height above a card's top edge to sit at: clears the card when you look at it and it pops up
    private static let perchClearance: Float = 0.03

    /// The flight loop; runs until the task is cancelled (Showroom closed)
    static func fly(_ butterfly: Entity, in root: Entity, perches: ButterflyPerches) async {
        var next = 0
        while !Task.isCancelled {
            // Flutter around neighbouring gigs: beat the wings, glide now and then
            for index in 0..<3 {
                guard !Task.isCancelled else { return }
                play(index == 1 ? .glide : .fly, on: butterfly)
                await hop(butterfly, to: wanderPoint(near: root), in: root)
            }
            // Land on the next perch (newest saved gig, then 2nd recent gig, …)
            let names = perches.names.filter { root.findEntity(named: $0) != nil }
            guard !names.isEmpty, let card = root.findEntity(named: names[next % names.count]) else { continue }
            next += 1
            let bounds = card.visualBounds(relativeTo: root)
            // Sits just above the top edge and a touch in front, so a card that lifts under your gaze
            // doesn't swallow it
            let edge = SIMD3<Float>(bounds.center.x, bounds.max.y, bounds.center.z)
            let perch = edge + SIMD3(0, perchClearance, 0) + towardViewer(edge) * 0.03
            play(.fly, on: butterfly)
            await hop(butterfly, to: perch + SIMD3(0, 0.12, 0) + towardViewer(perch) * 0.05, in: root)
            play(.glide, on: butterfly)
            await hop(butterfly, to: perch, in: root, landing: true)
            // A little chime from where it lands
            SoundFX.perch.play(on: butterfly)
            // Rest: slow wing beats, with a little hop up and back down halfway through
            play(.flap, on: butterfly, speed: 0.4)
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            play(.fly, on: butterfly)
            await hop(butterfly, to: perch + SIMD3(0, 0.05, 0) + towardViewer(perch) * 0.02, in: root)
            await hop(butterfly, to: perch, in: root, landing: true)
            play(.flap, on: butterfly, speed: 0.4)
            try? await Task.sleep(for: .seconds(2.5))
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
