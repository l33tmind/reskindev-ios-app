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
        case .acceptDelivery: "Review Delivery"
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
    /// "Ask for changes" inside the accept form swaps the form to a revision request (and back)
    @State private var askingForChanges = false
    /// Same as the iOS app: accepting never asks for a review. Afterwards an "All done!" step offers one,
    /// now or later ("Leave a review" stays on the order).
    @State private var acceptedHere = false
    @State private var reviewingNow = false

    /// The action the form is showing right now
    private var current: OrderAction { askingForChanges ? .revision : action }
    /// The order is (now) completed, so the buyer form is a review
    private var isCompleted: Bool { order.isCompleted || acceptedHere }
    /// Buyer looking at a delivery that isn't accepted yet
    private var isAcceptingDelivery: Bool { current == .acceptDelivery && !isCompleted }

    var body: some View {
        if acceptedHere && !reviewingNow {
            allDone
        } else {
            form
        }
    }

    /// Shown right after accepting: celebrate first, then a light, skippable review ask
    private var allDone: some View {
        VStack(spacing: 16) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.brandGreen)
                .symbolEffect(.bounce, options: .nonRepeating)
            Text("All done!").font(.title.weight(.bold))
            Text("The order is complete and \(sellerFirstName) has been paid. A quick review helps other buyers. It takes 20 seconds, and you can also do it later from My Orders.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button("Later") { onDone("Order complete! You can leave a review any time.") }
                    .buttonStyle(GlassOutlineButtonStyle())
                Button {
                    withAnimation { reviewingNow = true }
                } label: {
                    Label("Leave a review", systemImage: "star.fill")
                }
                .buttonStyle(GlassOutlineButtonStyle(prominent: true))
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            if isAcceptingDelivery {
                Label("Your delivery is here", systemImage: "shippingbox.fill")
                    .font(.title2.weight(.semibold))
            } else {
                Label(formTitle, systemImage: current.icon)
                    .font(.title2.weight(.semibold))
            }
            Text(order.gigTitle).font(.headline).foregroundStyle(.secondary).lineLimit(1)

            if isAcceptingDelivery { acceptFields } else { fields }

            if let errorMessage {
                Text(errorMessage).font(.callout).foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                if isAcceptingDelivery {
                    // The way out is as easy to reach as Accept, so accepting never feels like a trap
                    Button {
                        withAnimation { askingForChanges = true }
                    } label: {
                        Label("Ask for changes", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(GlassOutlineButtonStyle())
                } else if askingForChanges {
                    Button("Back to delivery") { withAnimation { askingForChanges = false } }
                        .buttonStyle(GlassOutlineButtonStyle())
                } else {
                    Button("Back", action: onCancel)
                        .buttonStyle(GlassOutlineButtonStyle())
                }
                Button {
                    Task { await submit() }
                } label: {
                    if isWorking { ProgressView() } else { Text(submitTitle) }
                }
                .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                .disabled(!isValid || isWorking)
            }

            if isAcceptingDelivery {
                Button("Not now", action: onCancel)
                    .buttonStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear { if action == .requirements { text = order.requirements } }
    }

    private var formTitle: String {
        current == .acceptDelivery && isCompleted ? "Rate your order" : current.title
    }

    /// Full name: first names alone are often ambiguous ("Guest 4828" → "Guest")
    private var sellerFirstName: String {
        let name = order.sellerName.trimmed
        return name.isEmpty ? "the seller" : name
    }

    /// The delivery link, or the first link in the message (the Flutter app puts links in the note)
    private var filesURL: URL? {
        if let url = URL(string: order.deliveryLink.trimmed), url.scheme?.hasPrefix("http") == true { return url }
        let text = order.deliveryMessage
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        return detector?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))?.url
    }

    /// Accept = see what arrived next to what you asked for, know exactly what happens next,
    /// and see that "Ask for changes" is free. The review comes after, and only if they want.
    @ViewBuilder
    private var acceptFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("From \(sellerFirstName)").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Text(order.deliveryMessage.isEmpty ? "\(sellerFirstName) marked the work as delivered. Check the chat for files." : order.deliveryMessage)
                .font(.body)
                .lineLimit(8)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            if let url = filesURL {
                Link(destination: url) {
                    Label("Open the files", systemImage: "arrow.up.right.square")
                        .font(.callout.weight(.semibold))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.brandGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

        if !order.requirements.trimmed.isEmpty {
            DisclosureGroup {
                Text(order.requirements)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            } label: {
                Label("What you asked for", systemImage: "list.bullet.clipboard")
                    .font(.subheadline.weight(.semibold))
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            reassurance("checkmark.circle.fill", .brandGreen,
                        "Happy with it? Accept, and the order is done. \(sellerFirstName) gets paid.")
            reassurance("arrow.uturn.backward.circle.fill", .orange,
                        "Not quite right? Asking for changes is free and keeps the order open.")
            reassurance("bubble.left.fill", .blue,
                        "You can still message \(sellerFirstName) after the order is done.")
            if let delivered = order.deliveredAt {
                reassurance("clock.fill", .secondary,
                            "No rush. If you don't answer, it completes by itself on \(delivered.addingTimeInterval(3 * 86_400).formatted(.dateTime.weekday(.wide).day().month(.abbreviated))).")
            }
        }

    }

    private func reassurance(_ icon: String, _ color: Color, _ text: String) -> some View {
        Label {
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
        } icon: {
            // Same box for every symbol, so the four lines start at one edge
            Image(systemName: icon)
                .foregroundStyle(color)
                .imageScale(.medium)
                .frame(width: 24)
        }
    }

    @ViewBuilder
    private var reviewFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Communication").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            StarRatingPicker(rating: $review.communication)
        }
        VStack(alignment: .leading, spacing: 6) {
            Text(current == .acceptDelivery ? "Service as described" : "Buyer cooperation")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            StarRatingPicker(rating: $review.service)
        }
        Toggle(current == .acceptDelivery ? "Would recommend this seller" : "Would work with this buyer again",
               isOn: $review.recommend)
        GlassField(title: current == .acceptDelivery ? "Your review (optional)" : "Your review", text: $review.comment, axis: .vertical)
        hint(current == .acceptDelivery
             ? "Your review stays hidden until the seller reviews you back (or 14 days pass)."
             : "Submitting makes both reviews public.")
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
            GlassField(title: "What should \(sellerFirstName) change?", text: $text,
                       prompt: "E.g. Make the logo a bit bigger and use a darker green", axis: .vertical)
            hint("Free. The order stays open and \(sellerFirstName) delivers again.")
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
            reviewFields
        }
    }

    private var isValid: Bool {
        switch current {
        case .deliver: !text.trimmed.isEmpty
        // Accepting (and a buyer review) never needs a written comment
        case .acceptDelivery: true
        case .reviewBuyer: !review.comment.trimmed.isEmpty
        default: !text.trimmed.isEmpty
        }
    }

    private var submitTitle: String {
        switch current {
        case .acceptDelivery: isCompleted ? "Submit Review" : "Looks good, accept"
        case .revision: "Send to \(sellerFirstName)"
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
            switch current {
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
                onDone("Sent! \(sellerFirstName) will work on your changes.")
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
                if isCompleted {
                    try await OrderService.submitBuyerReview(order, review: input, session: session)
                    onDone("Thanks! Your review is saved.")
                } else {
                    try await OrderService.acceptDelivery(order, review: nil, session: session)
                    appModel.celebrate()
                    SoundFX.success.play()
                    withAnimation { acceptedHere = true }
                }
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
    @Environment(AppModel.self) private var appModel

    var body: some View {
        OrderActionForm(order: order, action: action, onCancel: { dismiss() }) { message in
            onDone(message)
            dismiss()
        }
        .padding(32)
        .frame(width: 560)
        .sheetPresence()
        .celebrations(appModel.celebration)
    }
}
