import Foundation
import GroupActivities
import Observation
import Combine

// MARK: - SharePlay: buyer and seller on FaceTime open the same delivery in the Theater together
// Videos stay in sync (play, pause, scrub) through AVPlayer's playback coordinator.

struct WatchTogetherActivity: GroupActivity {
    static let activityIdentifier = "com.reskindevdotcom.reskindev.watch-together"
    let item: TheaterItem

    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = "Review: \(item.title)"
        metadata.subtitle = "Reskindev delivery"
        metadata.type = .watchTogether
        return metadata
    }
}

@MainActor
@Observable
final class SharePlayCenter {
    static let shared = SharePlayCenter()

    /// The live session, while one is running
    private(set) var session: GroupSession<WatchTogetherActivity>?
    /// Someone started Watch Together: the home window opens this in the Theater
    var pendingItem: TheaterItem?

    /// Listens for sessions for the life of the app (started from the home window)
    func observe() async {
        for await session in WatchTogetherActivity.sessions() {
            self.session = session
            pendingItem = session.activity.item
            session.join()
            Task { [weak self] in
                for await state in session.$state.values {
                    if case .invalidated = state {
                        if self?.session === session { self?.session = nil }
                        break
                    }
                }
            }
        }
    }

    /// "Watch Together" in the Theater: starts SharePlay if a FaceTime call is on, else the system offers to start one
    func start(_ item: TheaterItem) async {
        _ = try? await WatchTogetherActivity(item: item).activate()
    }

    func isSharing(_ item: TheaterItem) -> Bool { session?.activity.item == item }
}
