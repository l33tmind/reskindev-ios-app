import SwiftUI
import StoreKit

/// Reskindev Pro: benefits, plan picker, subscribe / restore, and the active state
struct ProView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ProStore.self) private var store
    @Environment(AppModel.self) private var appModel
    @Environment(\.purchase) private var purchase
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL

    @State private var selectedID = ProStore.yearlyID
    @State private var showManage = false

    private static let appleSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!
    private static let googleSubscriptionsURL = URL(string: "https://play.google.com/store/account/subscriptions")!

    private var selectedProduct: Product? { store.products.first { $0.id == selectedID } }

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                hero
                if session.isPro {
                    activeCard
                } else {
                    if store.justSubscribed { celebration }
                    planPicker
                    subscribeButtons
                }
                benefits
                smallPrint
            }
            .padding(36)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Reskindev Pro")
        .task { await store.loadProducts() }
        .onChange(of: session.isPro) { _, isPro in
            if isPro, store.justSubscribed { appModel.celebrate() }
        }
        .manageSubscriptionsSheet(isPresented: $showManage)
        .errorAlert("Reskindev Pro", message: $store.errorMessage)
        .alert("Reskindev Pro", isPresented: Binding(get: { store.infoMessage != nil },
                                                     set: { if !$0 { store.infoMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.infoMessage ?? "")
        }
    }

    // MARK: Hero

    private var hero: some View {
        HStack(spacing: 22) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 96, height: 96)
                .background(LinearGradient(colors: [Color(red: 1, green: 0.84, blue: 0.4), Color.proAmber],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                .shadow(color: Color.proAmber.opacity(0.6), radius: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text("Reskindev Pro").font(.extraLargeTitle2.weight(.bold))
                    Image(systemName: "bolt.fill").font(.title).foregroundStyle(Color.proAmber).accessibilityHidden(true)
                }
                Text("Stand out, message any seller and share photos and videos before you order.")
                    .font(.title3).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Benefits

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What you get").font(.title2.weight(.semibold))
            BenefitRow(icon: "bolt.fill", title: "Pro badge",
                       detail: "A gold PRO badge next to your name on your profile, gigs and chats.")
            BenefitRow(icon: "message.fill", title: "Message any seller",
                       detail: "Start a conversation with any seller directly, no order needed.")
            BenefitRow(icon: "photo.on.rectangle.angled", title: "Photos & videos in every chat",
                       detail: "Send photos (up to 5 MB) and videos (up to 100 MB) before payment.")
            BenefitRow(icon: "checkmark.seal.fill", title: "Free identity verification",
                       detail: "Get the blue tick at no cost.", comingSoon: true)
            BenefitRow(icon: "headphones", title: "Priority support",
                       detail: "Your questions go to the front of the line.", comingSoon: true)
        }
        .padding(24)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }

    // MARK: Plans

    private var planPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose your plan").font(.title2.weight(.semibold))
            if store.loadingProducts && store.products.isEmpty {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            } else if store.products.isEmpty {
                VStack(spacing: 12) {
                    Text("Plans couldn't be loaded.").foregroundStyle(.secondary)
                    Button("Try Again") { Task { await store.loadProducts() } }
                        .buttonStyle(GlassOutlineButtonStyle())
                        .frame(width: 200)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                HStack(spacing: 16) {
                    if let yearly = store.yearly {
                        PlanCard(product: yearly, period: "per year", note: "2 months free",
                                 badge: "Save 17%", isSelected: selectedID == yearly.id) { selectedID = yearly.id }
                    }
                    if let monthly = store.monthly {
                        PlanCard(product: monthly, period: "per month", note: "Cancel any time",
                                 badge: nil, isSelected: selectedID == monthly.id) { selectedID = monthly.id }
                    }
                }
            }
        }
    }

    private var subscribeButtons: some View {
        VStack(spacing: 12) {
            Button {
                guard let product = selectedProduct else { return }
                Task { await store.purchase(product, using: purchase) }
            } label: {
                if store.purchasing {
                    ProgressView()
                } else if let product = selectedProduct {
                    Text("Subscribe for \(product.displayPrice)")
                } else {
                    Text("Subscribe")
                }
            }
            .buttonStyle(GlassOutlineButtonStyle(prominent: true, tint: Color.proAmber))
            .disabled(selectedProduct == nil || store.purchasing || store.restoring)

            Button {
                Task { await store.restore() }
            } label: {
                if store.restoring { ProgressView() } else { Text("Restore Purchases") }
            }
            .buttonStyle(GlassOutlineButtonStyle())
            .disabled(store.purchasing || store.restoring)
        }
    }

    private var celebration: some View {
        HStack(spacing: 14) {
            ProgressView()
            Text("Payment received! Turning on Pro for your account…").font(.headline)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.proAmber.opacity(0.15), in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }

    // MARK: Active

    private var activeCard: some View {
        let pro = session.pro
        let renews = pro.source == "apple" || pro.source == "google" ? pro.autoRenew : false
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProBadge(size: .large)
                Text(store.justSubscribed ? "Welcome to Pro!" : "You're a Pro member")
                    .font(.title2.weight(.semibold))
            }
            VStack(alignment: .leading, spacing: 8) {
                if let plan = pro.plan {
                    Label("\(plan.capitalized) plan", systemImage: "calendar")
                }
                Label(sourceText(pro.source), systemImage: "creditcard")
                if let date = pro.expiresAt {
                    Label("\(renews ? "Renews" : "Ends") on \(date.formatted(date: .long, time: .omitted))",
                          systemImage: renews ? "arrow.clockwise" : "hourglass")
                }
            }
            .font(.title3)

            switch pro.source {
            case "apple":
                Button { showManage = true } label: { Label("Manage Subscription", systemImage: "gearshape") }
                    .buttonStyle(GlassOutlineButtonStyle())
                    .frame(width: 320)
                Button("Open in App Store account settings") { openURL(Self.appleSubscriptionsURL) }
                    .buttonStyle(.plain).font(.footnote).foregroundStyle(.secondary)
            case "google":
                Text("You subscribed on Android. Manage it in Google Play.").foregroundStyle(.secondary)
                Button { openURL(Self.googleSubscriptionsURL) } label: { Label("Google Play Subscriptions", systemImage: "arrow.up.right.square") }
                    .buttonStyle(GlassOutlineButtonStyle())
                    .frame(width: 320)
            default:
                Text("This isn't a recurring subscription. Buy again before it ends to extend.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.proAmber.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous).stroke(Color.proAmber.opacity(0.5), lineWidth: 1.5))
    }

    private func sourceText(_ source: String?) -> String {
        switch source {
        case "apple": "Paid with the App Store"
        case "google": "Paid with Google Play"
        case "wallet": "Paid from your Reskindev wallet"
        case "admin": "Given by the Reskindev team"
        default: "Active"
        }
    }

    // MARK: Small print (App Store requirement)

    private var smallPrint: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(termsText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 18) {
                Button("Terms of Service") { openWindow(id: WindowID.page, value: WindowID.single) }
                Button("Privacy Policy") { openWindow(id: WindowID.page, value: WindowID.single) }
            }
            .buttonStyle(.plain)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.proAmber)
        }
    }

    private var termsText: String {
        let monthly = store.monthly?.displayPrice ?? "$7.99"
        let yearly = store.yearly?.displayPrice ?? "$79.99"
        return "Reskindev Pro is an auto-renewing subscription: \(monthly) per month or \(yearly) per year. "
            + "Payment is charged to your Apple Account when you confirm. The subscription renews automatically "
            + "at the same price unless it's cancelled at least 24 hours before the end of the current period. "
            + "Manage or cancel it any time in your App Store account settings."
    }
}

private struct BenefitRow: View {
    let icon: String
    let title: String
    let detail: String
    var comingSoon = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.proAmber)
                .frame(width: 48, height: 48)
                .background(Color.proAmber.opacity(0.15), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title).font(.headline)
                    if comingSoon {
                        Text("Coming soon")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.white.opacity(0.12), in: Capsule())
                    }
                }
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PlanCard: View {
    let product: Product
    let period: String
    let note: String
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(product.displayName.isEmpty ? period.capitalized : product.displayName)
                        .font(.headline)
                    Spacer()
                    if let badge {
                        Text(badge)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.proAmber, in: Capsule())
                    }
                }
                Text(product.displayPrice).font(.largeTitle.weight(.bold))
                Text(period).font(.subheadline).foregroundStyle(.secondary)
                Text(note).font(.footnote).foregroundStyle(Color.proAmber)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(isSelected ? 0.12 : 0.05),
                        in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .stroke(isSelected ? Color.proAmber : Color.white.opacity(0.25), lineWidth: isSelected ? 2.5 : 1)
            )
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .hoverEffect(.highlight)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel("\(product.displayName), \(product.displayPrice) \(period)")
    }
}
