import SwiftUI

/// Checkout sheet for a gig package (website app/order/[gigId]/[pkg]/page.js)
/// or a custom offer from chat (website app/checkout/custom/page.js)
struct CheckoutView: View {
    enum Item {
        case gig(GigModel, GigPackage)
        case offer(ChatMessage, Conversation)
    }
    let item: Item

    init(gig: GigModel, package: GigPackage) { item = .gig(gig, package) }
    init(offer: ChatMessage, in conversation: Conversation) { item = .offer(offer, conversation) }

    private var basePrice: Double {
        switch item {
        case .gig(_, let package): package.price
        case .offer(let message, _): message.offerPrice
        }
    }
    private var isOffer: Bool { if case .offer = item { true } else { false } }

    @Environment(SessionStore.self) private var session
    @Environment(ChatStore.self) private var chat
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    @State private var form = OrderService.CheckoutForm()
    @State private var feePercent: Double = 5
    @State private var couponCode = ""
    @State private var coupon: OrderService.Coupon?
    @State private var couponError: String?
    @State private var applyingCoupon = false
    @State private var submitting = false
    @State private var placedOrder = false
    @State private var errorMessage: String?
    @State private var noticeInBangla = false

    private var pricing: OrderService.Pricing {
        .init(base: basePrice, discount: coupon?.discount ?? 0, feePercent: feePercent)
    }
    private var walletCovers: Bool { session.walletBalance >= pricing.total }

    var body: some View {
        Group {
            if placedOrder {
                successView
            } else {
                HStack(alignment: .top, spacing: 28) {
                    ScrollView { formColumn.padding(.trailing, 8) }
                        .scrollIndicators(.hidden)
                    summaryColumn
                        .frame(width: 320)
                }
                .padding(32)
            }
        }
        .frame(width: 1000, height: 700)
        .task {
            feePercent = await OrderService.serviceFeePercent()
            // Saved phone from the profile, so most people only press "Place Order"
            if form.phone.isEmpty { form.phone = session.phone }
            // Custom offers: requirements start from the seller's offer description
            if case .offer(let message, _) = item, form.requirements.isEmpty { form.requirements = message.offerDescription }
        }
        .errorAlert("Order Error", message: $errorMessage)
    }

    // MARK: Form

    private var formColumn: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text(isOffer ? "Accept Custom Offer" : "Checkout").font(.extraLargeTitle2.weight(.semibold))
                Spacer()
                CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
            }

            notice

            section("Payment Method", icon: "creditcard") {
                HStack(spacing: 12) {
                    PaymentOption(title: "Offline Payment", subtitle: "Pay via Bank/Mobile Banking",
                                  isSelected: !form.payWithWallet) { form.payWithWallet = false }
                    PaymentOption(title: "Wallet Balance", subtitle: "Available: \(session.walletBalance.usd)",
                                  isSelected: form.payWithWallet) { form.payWithWallet = true }
                        .disabled(!walletCovers)
                        .opacity(walletCovers ? 1 : 0.45)
                }
            }

            // Only what's needed up front; everything optional is tucked away
            section("How can we reach you?", icon: "phone") {
                GlassField(title: "Phone number", text: $form.phone, prompt: "+880 1XXX-XXXXXX")
                if !session.phone.isEmpty && form.phone == session.phone {
                    Label("From your profile", systemImage: "checkmark.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            section("What do you need? (optional)", icon: "pencil") {
                GlassField(title: "You can also send details later in chat", text: $form.requirements,
                           prompt: "E.g. I need a 5-page website for my restaurant...", axis: .vertical)
            }

            DisclosureGroup("More details (optional)") {
                VStack(spacing: 12) {
                    GlassField(title: "Company / Brand name", text: $form.company)
                    GlassField(title: "Address", text: $form.address)
                }
                .padding(.top, 10)
            }
            .font(.headline)
        }
    }

    private var notice: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Notice", systemImage: "info.circle.fill").font(.headline).foregroundStyle(Color.starYellow)
                Spacer()
                Picker("Language", selection: $noticeInBangla) {
                    Text("EN").tag(false)
                    Text("বাংলা").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            Text(noticeInBangla
                 ? "এটি একটি রিয়েল-ওয়ার্ল্ড সার্ভিস: অর্ডার প্লেস করার পর আমাদের টিম আপনার সাথে যোগাযোগ করবে। কাজের বিস্তারিত আলোচনা এবং পেমেন্ট অফলাইনে সম্পন্ন করা হবে।"
                 : "This is a real-world service. After placing your order, our team will contact you to discuss project details and finalize payment arrangements offline.")
                .font(.callout)
        }
        .padding(18)
        .background(Color.starYellow.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).stroke(Color.starYellow.opacity(0.35), lineWidth: 1))
    }

    // MARK: Summary

    private var summaryColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Order Summary").font(.title2.weight(.semibold))

            summaryHeader

            Divider()

            // Coupon (gig checkout only, like the website) — hidden until asked for
            if !isOffer {
            DisclosureGroup("Have a coupon?") {
            HStack(spacing: 8) {
                TextField("Coupon code", text: $couponCode)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                Button {
                    Task { await applyCoupon() }
                } label: {
                    if applyingCoupon { ProgressView() } else { Text("Apply") }
                }
                .disabled(couponCode.trimmed.isEmpty || applyingCoupon)
            }
            if let couponError {
                Text(couponError).font(.caption).foregroundStyle(.red)
            } else if let coupon {
                Label("\(coupon.code) applied", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.brandGreen)
            }
            }
            .font(.subheadline)
            }

            priceRow("Subtotal", basePrice.usd)
            if pricing.discount > 0 { priceRow("Discount", "−\(pricing.discount.usd)") }
            priceRow("Service Fee (\(feePercent.formatted())%)", pricing.feeAmount.usd)
            Divider()
            HStack {
                Text("Total").font(.title3.weight(.semibold))
                Spacer()
                Text(pricing.total.usd).font(.title2.weight(.semibold))
            }

            Spacer()

            Button {
                Task { await placeOrder() }
            } label: {
                if submitting { ProgressView() } else { Text("Place Order • \(pricing.total.usd)") }
            }
            .buttonStyle(GlassOutlineButtonStyle(prominent: true))
            .disabled(submitting || form.phone.trimmed.isEmpty || session.isBlockedByAdmin)

            if session.isBlockedByAdmin {
                Text("Your account is suspended, so new orders are disabled.").font(.caption).foregroundStyle(.red)
            }

            if form.phone.trimmed.isEmpty {
                Text("Phone number is required.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }

    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 90))
                .foregroundStyle(Color.brandGreen)
                .shadow(color: Color.brandGreen.opacity(0.6), radius: 24)
                .symbolEffect(.bounce, options: .nonRepeating)
                .onAppear { SoundFX.success.play() }
            Text(isOffer ? "Offer Accepted!" : "Order Placed Successfully!").font(.extraLargeTitle2.weight(.semibold))
            Text("Your order is in My Orders, and its WorkStream chat is open in the Inbox.")
                .foregroundStyle(.secondary)
            Button("Done") { dismiss() }
                .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                .frame(width: 240)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var summaryHeader: some View {
        switch item {
        case .gig(let gig, let package):
            HStack(spacing: 14) {
                CachedImage(url: gig.imageUrl)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(gig.title).font(.headline).lineLimit(2)
                    Text("\(package.name.uppercased()) PACKAGE")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.brandGreen)
                }
            }
        case .offer(let message, let conversation):
            VStack(alignment: .leading, spacing: 6) {
                Label("Custom Offer", systemImage: "doc.badge.plus").font(.headline)
                Text("From \(conversation.names[message.senderId] ?? "Seller") · \(message.offerDays)-day delivery")
                    .font(.subheadline).foregroundStyle(.secondary)
                if !message.offerDescription.isEmpty {
                    Text(message.offerDescription).font(.caption).foregroundStyle(.secondary).lineLimit(4)
                }
            }
        }
    }

    // MARK: Actions

    private func applyCoupon() async {
        applyingCoupon = true
        couponError = nil
        do {
            coupon = try await OrderService.coupon(code: couponCode)
        } catch {
            coupon = nil
            couponError = error.friendlyMessage
        }
        applyingCoupon = false
    }

    private func placeOrder() async {
        submitting = true
        do {
            let result = switch item {
            case .gig(let gig, let package):
                try await OrderService.placeOrder(gig: gig, package: package, form: form,
                                                  pricing: pricing, coupon: coupon, session: session)
            case .offer(let message, let conversation):
                try await OrderService.placeCustomOrder(offer: message, in: conversation, form: form,
                                                        pricing: pricing, session: session)
            }
            if let chatID = result.chatID {
                chat.activeChatID = chatID
                appModel.selectedTab = .messages
            }
            if session.phone.isEmpty, !form.phone.trimmed.isEmpty {
                try? await session.updateProfile(displayName: session.displayName, username: session.username,
                                                  phone: form.phone.trimmed, country: session.country, bio: session.bio)
            }
            appModel.celebrate()
            withAnimation { placedOrder = true }
        } catch {
            errorMessage = error.friendlyMessage
        }
        submitting = false
    }

    // MARK: Pieces

    private func section<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(Color.brandGreen)
            content()
        }
    }

    private func priceRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }
}

private struct PaymentOption: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.brandGreen : Color.secondary)
                }
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(isSelected ? Color.brandGreen.opacity(0.12) : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .stroke(isSelected ? Color.brandGreen : Color.white.opacity(0.15), lineWidth: isSelected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
