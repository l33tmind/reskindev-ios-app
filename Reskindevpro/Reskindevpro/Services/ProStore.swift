import SwiftUI
import Observation
import StoreKit
import CryptoKit
import FirebaseFirestore
import FirebaseFunctions

// MARK: - Reskindev Pro status (users/{uid}.pro, written only by Cloud Functions)

struct ProStatus: Equatable {
    var active = false
    var plan: String?
    var source: String?
    var expiresAt: Date?
    var autoRenew = false

    /// Same rule on every app: active AND not yet expired
    var isPro: Bool { active && (expiresAt ?? .distantPast) > Date() }

    init() {}

    /// Reads the `pro` map of a users/{uid} document
    init(userData d: [String: Any]) {
        let pro = FS.map(d["pro"])
        active = pro["active"] as? Bool ?? false
        plan = FS.string(pro["plan"])
        source = FS.string(pro["source"])
        expiresAt = FS.date(pro["expiresAt"])
        autoRenew = pro["autoRenew"] as? Bool ?? false
    }

    static func isPro(_ userData: [String: Any]) -> Bool { ProStatus(userData: userData).isPro }
}

/// Pro flag for other people (gig cards, inbox rows, seller rows): each users doc is read once, then cached
@MainActor @Observable
final class ProDirectory {
    static let shared = ProDirectory()
    private(set) var proUIDs = Set<String>()
    @ObservationIgnored private var requested = Set<String>()

    func isPro(_ uid: String?) -> Bool {
        guard let uid, !uid.isEmpty, uid != "system" else { return false }
        if !requested.contains(uid) {
            requested.insert(uid)
            Task { [weak self] in
                guard let d = try? await Firestore.firestore().collection("users").document(uid).getDocument().data() else { return }
                self?.record(uid: uid, isPro: ProStatus.isPro(d))
            }
        }
        return proUIDs.contains(uid)
    }

    /// Fed by places that already read the users doc (chat header, seller profile, my own profile)
    func record(uid: String, isPro: Bool) {
        requested.insert(uid)
        if isPro { proUIDs.insert(uid) } else { proUIDs.remove(uid) }
    }
}

// MARK: - StoreKit 2 purchases → verifyAppleSubscription

@MainActor @Observable
final class ProStore {
    static let monthlyID = "reskindev.pro.monthly"
    static let yearlyID = "reskindev.pro.yearly"
    static let productIDs = [monthlyID, yearlyID]

    private(set) var products: [Product] = []
    private(set) var loadingProducts = false
    private(set) var purchasing = false
    private(set) var restoring = false
    /// Shown as the celebratory state after a successful purchase
    private(set) var justSubscribed = false
    var errorMessage: String?
    var infoMessage: String?

    var monthly: Product? { products.first { $0.id == Self.monthlyID } }
    var yearly: Product? { products.first { $0.id == Self.yearlyID } }

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var syncedUID: String?
    @ObservationIgnored private var uid: String?

    private var functions: Functions { Functions.functions(region: "asia-south1") }

    /// Called whenever the signed-in user changes
    func bind(uid: String?) {
        self.uid = uid
        if updatesTask == nil {
            // Renewals, Ask to Buy approvals, purchases made on another device
            updatesTask = Task { [weak self] in
                for await result in StoreKit.Transaction.updates {
                    await self?.handleBackground(result)
                }
            }
        }
        guard let uid, uid != syncedUID else { return }
        syncedUID = uid
        Task { await syncEntitlements(quiet: true) }
    }

    func loadProducts() async {
        guard products.isEmpty, !loadingProducts else { return }
        loadingProducts = true
        defer { loadingProducts = false }
        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { $0.price < $1.price }
            if products.isEmpty { errorMessage = "Subscriptions aren't available right now. Please try again later." }
        } catch {
            errorMessage = "Couldn't load the subscription plans. Check your connection and try again."
        }
    }

    /// Uses SwiftUI's PurchaseAction so visionOS can show the App Store sheet in the right window
    func purchase(_ product: Product, using purchase: PurchaseAction) async {
        guard let uid else { errorMessage = SessionError.signInRequired.errorDescription; return }
        purchasing = true
        justSubscribed = false
        defer { purchasing = false }
        do {
            let result = try await purchase(product, options: [.appAccountToken(Self.accountToken(for: uid))])
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = "The App Store couldn't confirm this purchase. Please try Restore Purchases."
                    return
                }
                try await verify(verification.jwsRepresentation)
                await transaction.finish()
                justSubscribed = true
            case .pending:
                infoMessage = "Your purchase is waiting for approval. Pro turns on as soon as it's approved."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = Self.friendly(error)
        }
    }

    /// Restore Purchases: refresh receipts from the App Store, then send what's active to Reskindev
    func restore() async {
        guard uid != nil else { errorMessage = SessionError.signInRequired.errorDescription; return }
        restoring = true
        defer { restoring = false }
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return
        } catch {
            errorMessage = Self.friendly(error)
            return
        }
        let found = await syncEntitlements(quiet: false)
        if found == 0, errorMessage == nil {
            infoMessage = "No active Reskindev Pro subscription was found for this Apple Account."
        }
    }

    /// Re-sends every current subscription entitlement to the backend. Returns how many were verified.
    @discardableResult
    func syncEntitlements(quiet: Bool) async -> Int {
        guard uid != nil else { return 0 }
        var count = 0
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            do {
                try await verify(result.jwsRepresentation)
                count += 1
            } catch {
                if !quiet { errorMessage = Self.friendly(error) }
            }
        }
        return count
    }

    private func handleBackground(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result, Self.productIDs.contains(transaction.productID) else { return }
        guard uid != nil else { return }   // left unfinished, redelivered after sign-in
        do {
            try await verify(result.jwsRepresentation)
            await transaction.finish()
        } catch {
            print("Pro: background verify failed:", error)
        }
    }

    private func verify(_ jws: String) async throws {
        _ = try await functions.httpsCallable("verifyAppleSubscription").call(["signedTransaction": jws])
        // users/{uid}.pro is updated by the function; the session's listener picks it up
    }

    /// Stable UUID from the Firebase uid, so App Store notifications can be matched to the account
    static func accountToken(for uid: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(uid.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50   // version 5 style
        bytes[8] = (bytes[8] & 0x3F) | 0x80   // RFC 4122 variant
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    private static func friendly(_ error: Error) -> String {
        if let error = error as? StoreKitError {
            switch error {
            case .networkError: return "You're offline. Check your connection and try again."
            case .notAvailableInStorefront: return "Reskindev Pro isn't available in your country's App Store yet."
            case .notEntitled: return "This Apple Account can't make purchases right now."
            case .userCancelled: return "Purchase cancelled."
            default: return "The App Store couldn't complete this. Please try again."
            }
        }
        if let error = error as? Product.PurchaseError {
            switch error {
            case .purchaseNotAllowed: return "Purchases are turned off on this device (Screen Time or account settings)."
            case .productUnavailable: return "This plan isn't available right now."
            default: return "The App Store couldn't complete this purchase. Please try again."
            }
        }
        let ns = error as NSError
        if ns.domain == FunctionsErrorDomain {
            // HttpsError from verifyAppleSubscription carries a friendly message
            if ns.code == FunctionsErrorCode.unauthenticated.rawValue { return "Please sign in again, then tap Restore Purchases." }
            if [FunctionsErrorCode.unavailable.rawValue, FunctionsErrorCode.deadlineExceeded.rawValue].contains(ns.code) {
                return "Your purchase went through, but Reskindev couldn't confirm it yet. Tap Restore Purchases in a moment."
            }
            return ns.localizedDescription
        }
        return error.friendlyMessage
    }
}
