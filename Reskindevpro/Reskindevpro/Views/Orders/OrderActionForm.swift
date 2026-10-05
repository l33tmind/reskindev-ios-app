import SwiftUI

/// Every order action the website's WorkStream modals offer, as one form
enum OrderAction: String, Identifiable {
    case requirements, deliver, revision, cancel, escalate, moreTime, acceptDelivery, reviewBuyer
    var id: String { rawValue }

    var title: String {
        switch self {
        case .requirements: "Submit Requirements"
        case .deliver: "Deliver Final Work"
        case .revision: "Request Revision"
        case .cancel: "Request Cancellation"
        case .escalate: "Escalate to Admin"
        case .moreTime: "Request More Time"
        case .acceptDelivery: "Accept & Rate Delivery"
        case .reviewBuyer: "Rate the Buyer"
        }
    }

    var icon: String {
        switch self {
        case .requirements: "doc.text"
        case .deliver: "shippingbox.fill"
        case .revision: "arrow.uturn.backward"
        case .cancel: "xmark.octagon"
        case .escalate: "exclamationmark.shield"
        case .moreTime: "clock.badge.questionmark"
        case .acceptDelivery: "checkmark.seal.fill"
        case .reviewBuyer: "star.fill"
        }
    }
}

struct OrderActionForm: View {
    let order: OrderModel
    let action: OrderAction
    var onCancel: () -> Void = {}
    var onDone: (String) -> Void = { _ in }

    @Environment(SessionStore.self) private var session
    @Environment(AppModel.self) private var appModel
    @State private var text = ""
    @State private var link = ""
    @State private var days = 1
    @State private var review = OrderService.ReviewInput()
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(action.title, systemImage: action.icon)
                .font(.title2.weight(.semibold))
            Text(order.gigTitle).font(.headline).foregroundStyle(.secondary).lineLimit(1)

            fields

            if let errorMessage {
                Text(errorMessage).font(.callout).foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button("Back", action: onCancel)
                    .buttonStyle(GlassOutlineButtonStyle())
                Button {
                    Task { await submit() }
                } label: {
                    if isWorking { ProgressView() } else { Text(submitTitle) }
                }
                .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                .disabled(!isValid || isWorking)
            }
        }
        .onAppear { if action == .requirements { text = order.requirements } }
    }

    @ViewBuilder
    private var fields: some View {
        switch action {
        case .requirements:
            GlassField(title: "Describe what you need", text: $text,
                       prompt: "E.g. I need a 5-page website for my restaurant...", axis: .vertical)
            hint("Submitting starts the seller's delivery countdown.")
        case .deliver:
            GlassField(title: "Message to the buyer", text: $text, axis: .vertical)
            GlassField(title: "Delivery link (Drive, Dropbox, GitHub…)", text: $link, prompt: "https://")
        case .revision:
            GlassField(title: "What should be changed?", text: $text, axis: .vertical)
        case .cancel, .escalate:
            GlassField(title: "Reason", text: $text, axis: .vertical)
            hint(action == .cancel
                 ? "The other side can accept or decline. Accepted cancellations are refunded by Reskindev."
                 : "The Reskindev admin team will review this order and contact both sides.")
        case .moreTime:
            Stepper("Extra days: \(days)", value: $days, in: 1...30)
                .font(.headline)
            GlassField(title: "Why do you need more time?", text: $text, axis: .vertical)
        case .acceptDelivery, .reviewBuyer:
            VStack(alignment: .leading, spacing: 6) {
                Text("Communication").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                StarRatingPicker(rating: $review.communication)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(action == .acceptDelivery ? "Service as described" : "Buyer cooperation")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                StarRatingPicker(rating: $review.service)
            }
            Toggle(action == .acceptDelivery ? "Would recommend this seller" : "Would work with this buyer again",
                   isOn: $review.recommend)
            GlassField(title: "Your review", text: $review.comment, axis: .vertical)
            hint(action == .acceptDelivery
                 ? "Your review stays hidden until the seller reviews you back (or 14 days pass)."
                 : "Submitting makes both reviews public.")
        }
    }

    private var isValid: Bool {
        switch action {
        case .deliver: !text.trimmed.isEmpty
        case .acceptDelivery, .reviewBuyer: !review.comment.trimmed.isEmpty
        default: !text.trimmed.isEmpty
        }
    }

    private var submitTitle: String {
        switch action {
        case .acceptDelivery: "Accept & Complete Order"
        case .reviewBuyer: "Submit Review"
        case .deliver: "Deliver Now"
        default: "Send"
        }
    }

    private func submit() async {
        isWorking = true
        errorMessage = nil
        do {
            let t = text.trimmed
            switch action {
            case .requirements:
                try await OrderService.submitRequirements(order, text: t, session: session)
                onDone("Requirements submitted! The countdown timer has started.")
            case .deliver:
                try await OrderService.deliver(order, message: t, link: link.trimmed, session: session)
                appModel.celebrate()
                SoundFX.success.play()
                onDone("Order delivered successfully!")
            case .revision:
                try await OrderService.requestRevision(order, note: t, session: session)
                onDone("Revision requested successfully!")
            case .cancel:
                try await OrderService.requestCancel(order, reason: t, session: session)
                onDone("Cancellation request sent.")
            case .escalate:
                try await OrderService.escalate(order, reason: t, session: session)
                onDone("Order escalated to Admin successfully.")
            case .moreTime:
                try await OrderService.requestExtension(order, days: days, reason: t, session: session)
                onDone("Extension request sent to the buyer.")
            case .acceptDelivery:
                var input = review
                input.comment = review.comment.trimmed
                try await OrderService.acceptDelivery(order, review: input, session: session)
                appModel.celebrate()
                onDone("Delivery accepted & review submitted!")
            case .reviewBuyer:
                var input = review
                input.comment = review.comment.trimmed
                try await OrderService.submitSellerReview(order, review: input, session: session)
                appModel.celebrate()
                onDone("Review submitted. Both reviews are now public!")
            }
        } catch {
            errorMessage = error.friendlyMessage
        }
        isWorking = false
    }

    private func hint(_ text: String) -> some View {
        Label(text, systemImage: "info.circle")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

/// Sheet wrapper used from the chat and the orders panel
struct OrderActionSheet: View {
    let order: OrderModel
    let action: OrderAction
    var onDone: (String) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        OrderActionForm(order: order, action: action, onCancel: { dismiss() }) { message in
            onDone(message)
            dismiss()
        }
        .padding(32)
        .frame(width: 560)
        .sheetPresence()
    }
}
