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
    /// Turn applied on top of "face the direction of travel": this model's head points +Z, so turn it
    /// half way round or it flies tail first
    static var forwardYaw: Float = .pi

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
    /// Where the feet are in model units (Y-up; feet at y ≈ 0), so the container's origin is under the
    /// butterfly and "perch at the card's edge" puts its feet on the edge
    private static let modelCentre: SIMD3<Float> = [-5, 0, -4]

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

    /// Which wing animation is playing, so a speed change doesn't restart it
    private struct WingState: Component {
        var clip: Clip
        var controller: AnimationPlaybackController
    }

    /// Switches the wings to a clip (looping, short blend), or just changes the beat if it's already playing
    @discardableResult
    static func play(_ clip: Clip, on butterfly: Entity, speed: Float = 1) -> AnimationPlaybackController? {
        if let state = butterfly.components[WingState.self], state.clip == clip, state.controller.isPlaying {
            state.controller.speed = speed
            return state.controller
        }
        let model = butterfly.findEntity(named: "model") ?? butterfly
        guard let animation = clips[clip] ?? clips[.flap] ?? model.availableAnimations.first else { return nil }
        let controller = model.playAnimation(animation.repeat(), transitionDuration: 0.2, startsPaused: false)
        controller.speed = speed
        butterfly.components.set(WingState(clip: clip, controller: controller))
        return controller
    }

    /// Plays the resting wing animation forever (Welcome screen)
    @discardableResult
    static func flap(_ butterfly: Entity) -> AnimationPlaybackController? {
        play(.flap, on: butterfly)
    }

    /// Feet on the card's top edge (cards grow downward from that edge when you look at them)
    private static let perchClearance: Float = 0.004

    /// The flight loop; runs until the task is cancelled (Showroom closed)
    static func fly(_ butterfly: Entity, in root: Entity, perches: ButterflyPerches) async {
        var next = 0
        while !Task.isCancelled {
            // Flutter around neighbouring gigs: beat the wings, glide now and then
            for _ in 0..<3 {
                guard !Task.isCancelled else { return }
                await hop(butterfly, to: wanderPoint(near: root), in: root)
            }
            // Land on the next perch (newest saved gig, then 2nd recent gig, …)
            let names = perches.names.filter { root.findEntity(named: $0) != nil }
            guard !names.isEmpty, let card = root.findEntity(named: names[next % names.count]) else { continue }
            next += 1
            let bounds = card.visualBounds(relativeTo: root)
            // Right on the top edge
            let edge = SIMD3<Float>(bounds.center.x, bounds.max.y, bounds.center.z)
            let perch = edge + SIMD3(0, perchClearance, 0)
            await hop(butterfly, to: perch + SIMD3(0, 0.12, 0) + towardViewer(perch) * 0.05, in: root)
            await hop(butterfly, to: perch, in: root, landing: true)
            // A little chime from where it lands
            SoundFX.perch.play(on: butterfly)
            // Rest: slow wing beats, with a little hop up and back down halfway through
            play(.flap, on: butterfly, speed: 0.4)
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            await hop(butterfly, to: perch + SIMD3(0, 0.05, 0) + towardViewer(perch) * 0.02, in: root)
            await hop(butterfly, to: perch, in: root, landing: true)
            play(.flap, on: butterfly, speed: 0.4)
            try? await Task.sleep(for: .seconds(2.5))
        }
    }

    // MARK: Moves

    /// One flight between two points, the way a butterfly really goes: a wobbly path in short legs,
    /// fast hard beats when climbing, slower beats on the level, wings spread to glide down,
    /// and a gentle glide in to land
    private static func hop(_ butterfly: Entity, to target: SIMD3<Float>, in root: Entity, landing: Bool = false) async {
        let start = butterfly.position(relativeTo: root)
        let distance = simd_distance(start, target)
        guard distance > 0.01 else { return }

        // ~12 cm legs, each nudged up/down and sideways (not the last one: it has to arrive exactly)
        let legs = max(2, Int((distance / 0.12).rounded()))
        let side = simd_normalize(simd_cross(target - start, [0, 1, 0]) + [0.0001, 0, 0])
        var current = start
        for leg in 1...legs {
            guard !Task.isCancelled else { return }
            let t = Float(leg) / Float(legs)
            var next = start + (target - start) * t
            if leg < legs {
                next.y += Float.random(in: -0.035...0.04)
                next += side * Float.random(in: -0.03...0.03)
            }

            let lastLeg = leg == legs
            let rise = next.y - current.y
            // Wings and flight speed (m/s) for this leg
            let clip: Clip
            let beat: Float
            var metresPerSecond: Float
            if landing && lastLeg {
                clip = .glide; beat = 0.7; metresPerSecond = speed * 0.45
            } else if rise > 0.012 {
                clip = .fly; beat = .random(in: 1.4...1.75); metresPerSecond = speed * 0.8     // climbing: hard work
            } else if rise < -0.02 {
                clip = .glide; beat = .random(in: 0.8...1.0); metresPerSecond = speed * 1.15  // sliding down
            } else if Float.random(in: 0...1) < 0.22 {
                clip = .glide; beat = 0.9; metresPerSecond = speed * 1.05                    // a short glide
            } else {
                clip = .fly; beat = .random(in: 0.9...1.3); metresPerSecond = speed           // cruising
            }
            if landing { metresPerSecond *= 0.7 }
            play(clip, on: butterfly, speed: beat)

            let duration = TimeInterval(max(0.18, simd_distance(current, next) / metresPerSecond))
            var transform = butterfly.transform
            transform.translation = next
            transform.rotation = facing(from: current, to: next)
            butterfly.move(to: transform, relativeTo: root, duration: duration,
                           timingFunction: lastLeg ? .easeOut : leg == 1 ? .easeIn : .linear)
            try? await Task.sleep(for: .seconds(duration))
            current = next
        }
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
