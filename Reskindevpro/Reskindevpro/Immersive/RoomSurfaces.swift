import ARKit
import RealityKit

/// Finds tables, desks and seats in your room (ARKit plane detection) so the Showroom butterfly can land
/// on them. Needs the person's OK to use their surroundings; without it (or in the simulator) there are
/// simply no room spots and the butterfly sticks to the gig cards.
@MainActor
final class RoomSurfaces {
    private let session = ARKitSession()
    private let planes = PlaneDetectionProvider(alignments: [.horizontal])
    private var spots: [UUID: SIMD3<Float>] = [:]

    /// Runs until the Showroom closes (cancel the task), keeping `perches.roomSpots` current
    func run(updating perches: ButterflyPerches) async {
        guard PlaneDetectionProvider.isSupported else { return }
        let auth = await session.requestAuthorization(for: [.worldSensing])
        guard auth[.worldSensing] == .allowed else { return }
        do {
            try await session.run([planes])
        } catch {
            return
        }
        defer { session.stop() }

        for await update in planes.anchorUpdates {
            if Task.isCancelled { break }
            let anchor = update.anchor
            if update.event == .removed || !Self.isPerch(anchor) {
                spots[anchor.id] = nil
            } else {
                spots[anchor.id] = Self.centre(of: anchor)
            }
            perches.roomSpots = Array(spots.values)
        }
    }

    /// Tables and seats, big enough to land on, at a sensible height (not the floor)
    private static func isPerch(_ anchor: PlaneAnchor) -> Bool {
        guard anchor.classification == .table || anchor.classification == .seat else { return false }
        let extent = anchor.geometry.extent
        guard extent.width * extent.height > 0.04 else { return false }
        let height = centre(of: anchor).y
        return (0.3...1.6).contains(height)
    }

    /// Middle of the plane, in world space (the Showroom's coordinate space)
    private static func centre(of anchor: PlaneAnchor) -> SIMD3<Float> {
        let local = anchor.geometry.extent.anchorFromExtentTransform.columns.3
        let world = anchor.originFromAnchorTransform * local
        return [world.x, world.y, world.z]
    }
}
