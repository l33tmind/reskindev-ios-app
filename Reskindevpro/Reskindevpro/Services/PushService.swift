import SwiftUI
import Observation
import UserNotifications
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

// MARK: - Push notifications (chat messages + order updates)
//
// The Cloud Function `sendChatPushNotification` pushes to users/{uid}.fcmToken, which the iOS app owns.
// Overwriting it would silence the iPhone, so this device adds its token to users/{uid}.fcmTokens
// (an array, one per extra device) — the function sends to both (functions/index.js).

@Observable
final class PushService {
    static let shared = PushService()

    /// Chat to open after the user taps a notification ("/chat/{id}" route from the Cloud Function)
    var pendingChatID: String?

    @ObservationIgnored private(set) var token: String?
    @ObservationIgnored private var savedFor: String?

    /// Ask once the person is signed in (not at first launch), then register with APNs
    func requestPermissionIfNeeded() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
            }
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func didReceive(token: String?) {
        self.token = token
        saveToken()
    }

    /// users/{uid}.fcmTokens ∪ token
    func saveToken() {
        guard let token, let uid = Auth.auth().currentUser?.uid, savedFor != uid + token else { return }
        savedFor = uid + token
        Firestore.firestore().collection("users").document(uid)
            .setData(["fcmTokens": FieldValue.arrayUnion([token])], merge: true)
    }

    /// Call before signing out so the old account stops getting this device's pushes
    func removeToken(for uid: String) {
        guard let token else { return }
        savedFor = nil
        Firestore.firestore().collection("users").document(uid)
            .updateData(["fcmTokens": FieldValue.arrayRemove([token])])
    }

    func handleTap(userInfo: [AnyHashable: Any]) {
        guard let route = userInfo["route"] as? String, route.hasPrefix("/chat/") else { return }
        pendingChatID = String(route.dropFirst("/chat/".count))
    }
}

// MARK: - App delegate: APNs ↔ Firebase Messaging, foreground banners, taps

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Tell Firebase which APNs server this token belongs to. Left to guess (`apnsToken =`), it can pick the
        // wrong one for a build run from Xcode, and APNs then rejects it as "Invalid APNs credential".
        #if DEBUG
        Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
        #else
        Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
        #endif
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🔔 APNs registration failed:", error.friendlyMessage)
    }

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in PushService.shared.didReceive(token: fcmToken) }
    }

    /// Show banners while the app is open too
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run { PushService.shared.handleTap(userInfo: userInfo) }
    }
}
