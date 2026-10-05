import Foundation
import FirebaseFirestore

/// One rule for every order value, shared with the website and the iOS/Android app:
/// at least $5, in steps of $5 (5, 10, 15, ...). Admins can change both in settings/global
/// (minOrderPrice, priceStep); without them the defaults below apply.
struct PricingRules {
    var min: Double = 5
    var step: Double = 5

    static func load() async -> PricingRules {
        let d = (try? await Firestore.firestore().collection("settings").document("global").getDocument().data()) ?? nil
        let min = FS.double(d?["minOrderPrice"]) ?? 5
        let step = FS.double(d?["priceStep"]) ?? 5
        return PricingRules(min: min > 0 ? min : 5, step: step > 0 ? step : 5)
    }

    private func fmt(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(v) }

    /// nil when the price is fine, otherwise a message for the user
    func check(_ value: Double?) -> String? {
        guard let value else { return "Enter a price." }
        if value < min { return "The minimum order is $\(fmt(min))." }
        // Work in cents so float noise can't reject a good value
        if Int((value * 100).rounded()) % Int((step * 100).rounded()) != 0 {
            return "Prices go up in steps of $\(fmt(step)) (\(fmt(min)), \(fmt(min + step)), \(fmt(min + 2 * step))…)."
        }
        return nil
    }
}
