import SwiftUI

/// Vertical order timeline with the details and actions of each step
/// (website app/inbox/page.js → WorkspaceTimelineDetails)
struct WorkspaceTimeline: View {
    let order: OrderModel
    var onAction: (OrderAction) -> Void

    @Environment(SessionStore.self) private var session
    @State private var expanded: Int?
    @State private var isWorking = false
    @State private var errorMessage: String?

    private let labels = ["Payment", "Requirements", "Processing", "Delivered", "Completed"]

    private var current: Int {
        if let step = order.timelineStep { return step }
        if order.status == "cancelled" { return 4 }
        return order.isCancelRequested ? 2 : 0
    }
    private var isBuyer: Bool { order.isBuyer(session.uid) }
    private var isSeller: Bool { order.isSeller(session.uid) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if order.isCancelRequested { cancelBanner.padding(.bottom, 18) }

            ForEach(labels.indices, id: \.self) { index in
                step(index)
            }
        }
        .errorAlert("Action failed", message: $errorMessage)
    }

    // MARK: Step shell

    private func step(_ index: Int) -> some View {
        let isActive = index == current
        let isPassed = index < current
        let isOpen = (expanded ?? current) == index

        return HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.snappy) { expanded = isOpen ? -1 : index }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isPassed ? Color.brandGreen : Color.black.opacity(0.25))
                            .frame(width: 32, height: 32)
                        Circle()
                            .stroke(isActive || isPassed ? Color.brandGreen : Color.white.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 32, height: 32)
                        if isPassed {
                            Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                        } else if isActive {
                            Circle().fill(Color.brandGreen).frame(width: 12, height: 12)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
                .shadow(color: isActive ? Color.brandGreen.opacity(0.7) : .clear, radius: 10)
                .accessibilityLabel("\(labels[index]) step")

                if index < labels.count - 1 {
                    Capsule()
                        .fill(index < current ? Color.brandGreen : Color.white.opacity(0.15))
                        .frame(width: 2)
                        .frame(minHeight: 24)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(labels[index].uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.9)
                    .foregroundStyle(isActive ? Color.brandGreen : (isPassed ? Color.primary : Color.secondary))
                    .padding(.top, 12)
                if isOpen {
                    stepContent(index)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Step content

    @ViewBuilder
    private func stepContent(_ index: Int) -> some View {
        switch index {
        case 0: paymentStep
        case 1: requirementsStep
        case 2: processingStep
        case 3: deliveredStep
        default: completedStep
        }
    }

    private var paymentStep: some View {
        box {
            Text(order.gigTitle).font(.headline)
            HStack {
                Text("#\(String(order.id.suffix(6)).uppercased())").font(.caption.weight(.semibold))
                Spacer()
                StatusBadge(order: order)
            }
            Divider()
            HStack {
                Text("Amount Secured").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text(order.price.usd).font(.headline).foregroundStyle(Color.brandGreen)
            }
            if order.isPendingPayment {
                note("Our team will contact the buyer to finalize payment.")
            }
        }
    }

    @ViewBuilder
    private var requirementsStep: some View {
        if !order.requirements.isEmpty {
            box(tint: .blue) {
                Text(order.requirements).font(.callout).textSelection(.enabled)
                if !order.credentials.isEmpty {
                    Divider()
                    Text("CREDENTIALS").font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(.blue)
                    Text(order.credentials).font(.callout.monospaced()).textSelection(.enabled)
                }
                if order.needsRequirements && isBuyer {
                    actionButton(.requirements, prominent: false, title: "Edit & Submit Requirements")
                }
            }
        } else if current >= 1 {
            if order.needsRequirements {
                box {
                    note("Waiting for the buyer to submit requirements…")
                    if isBuyer { actionButton(.requirements) }
                }
            } else {
                box(tint: .blue) { Text("Requirements verified & accepted.").font(.callout.weight(.semibold)) }
            }
        }
    }

    @ViewBuilder
    private var processingStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if order.isTimerRunning {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = order.dueDate.timeIntervalSince(context.date)
                    let late = remaining < 0
                    VStack(spacing: 4) {
                        Label(late ? "LATE BY" : "TIME LEFT TO DELIVER", systemImage: "clock")
                            .font(.caption.weight(.semibold))
                        Text(Self.countdown(abs(remaining)))
                            .font(.system(.title, design: .rounded).monospacedDigit().weight(.semibold))
                    }
                    .foregroundStyle(late ? Color.red : Color.brandGreen)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background((late ? Color.red : Color.brandGreen).opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }

            if let ext = order.extensionRequest {
                box(tint: .starYellow) {
                    Label("Seller asked for \(ext.days) more day(s)", systemImage: "clock.badge.questionmark").font(.headline)
                    if !ext.reason.isEmpty { Text(ext.reason).font(.callout).foregroundStyle(.secondary) }
                    if isBuyer {
                        HStack {
                            Button("Accept") { respondExtension(ext.days, accept: true) }
                                .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                            Button("Decline") { respondExtension(ext.days, accept: false) }
                                .buttonStyle(GlassOutlineButtonStyle())
                        }
                        .disabled(isWorking)
                    } else {
                        note("Waiting for the buyer to respond.")
                    }
                }
            } else if order.isInProgress && isSeller {
                actionButton(.moreTime, prominent: false)
            }

            if order.status == "revision", !order.revisionNote.isEmpty {
                box(tint: .orange) {
                    Text("REVISION REQUESTED").font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(.orange)
                    Text(order.revisionNote).font(.callout)
                }
            }
            if order.status == "disputed" {
                box(tint: .orange) {
                    Label("Disputed (Admin Review)", systemImage: "exclamationmark.shield.fill").font(.headline).foregroundStyle(.orange)
                    Text("This order has been escalated to the admin team for resolution. Please wait for an update.")
                        .font(.callout)
                }
            }
            if order.isInProgress && isSeller {
                actionButton(.deliver)
            }
        }
    }

    @ViewBuilder
    private var deliveredStep: some View {
        if !order.deliveryMessage.isEmpty || !order.deliveryLink.isEmpty {
            box(tint: .brandGreen) {
                if !order.deliveryMessage.isEmpty { Text(order.deliveryMessage).font(.callout).textSelection(.enabled) }
                if let url = URL(string: order.deliveryLink), !order.deliveryLink.isEmpty {
                    TheaterButton(item: TheaterItem(orderID: order.id, title: order.gigTitle,
                                                    link: order.deliveryLink, message: order.deliveryMessage))
                    Link(destination: url) { Label("View Attachment", systemImage: "arrow.up.right.square") }
                        .font(.headline)
                }
                if order.isDelivered && isBuyer {
                    actionButton(.acceptDelivery)
                    actionButton(.revision, prominent: false)
                }
            }
        } else if current >= 3 {
            box { note("Waiting for review") }
        }
    }

    @ViewBuilder
    private var completedStep: some View {
        if order.status == "cancelled" {
            box(tint: .red) { Label("Order cancelled", systemImage: "xmark.circle.fill").font(.headline).foregroundStyle(.red) }
        } else if let review = order.buyerReview {
            VStack(alignment: .leading, spacing: 12) {
                if order.isReviewPublic || isBuyer {
                    box {
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: i < review.stars ? "star.fill" : "star").foregroundStyle(Color.starYellow)
                            }
                            Text(String(format: "%.1f", review.rating)).font(.headline).padding(.leading, 6)
                        }
                        Text(review.comment.isEmpty ? "No written feedback provided." : "“\(review.comment)”")
                            .font(.callout.italic())
                            .foregroundStyle(.secondary)
                    }
                } else {
                    box {
                        Label("The buyer's review is hidden until you submit your review.", systemImage: "star.slash")
                            .font(.callout.weight(.semibold))
                    }
                }
                // Both reviews are public: show the seller's side too
                if order.isReviewPublic, let sellerReview = order.sellerReview {
                    box(tint: .blue) {
                        Text("SELLER'S REVIEW OF THE BUYER").font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(.blue)
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: i < sellerReview.stars ? "star.fill" : "star").foregroundStyle(Color.starYellow)
                            }
                            Text(String(format: "%.1f", sellerReview.rating)).font(.headline).padding(.leading, 6)
                        }
                        if !sellerReview.comment.isEmpty {
                            Text("“\(sellerReview.comment)”").font(.callout.italic()).foregroundStyle(.secondary)
                        }
                    }
                }
                if isSeller && order.sellerReview == nil {
                    box(tint: .blue) {
                        Text("Leave a Review for the Buyer").font(.headline)
                        Text("The buyer has rated your work. Rate your experience with them to see their feedback.")
                            .font(.callout).foregroundStyle(.secondary)
                        actionButton(.reviewBuyer)
                    }
                }
            }
        } else if order.isCompleted {
            box(tint: .brandGreen) {
                Label("Order Completed", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(Color.brandGreen)
                if isBuyer { actionButton(.acceptDelivery, prominent: false, title: "Leave a Review") }
            }
        }
    }

    // MARK: Cancel request banner

    private var cancelBanner: some View {
        let requestedBySeller = order.status == "cancel_requested_by_freelancer"
        let canRespond = requestedBySeller ? isBuyer : isSeller
        return box(tint: .red) {
            Label(requestedBySeller ? "Seller requested cancellation" : "Buyer requested cancellation",
                  systemImage: "xmark.octagon.fill")
                .font(.headline)
                .foregroundStyle(.red)
            if !order.cancelReason.isEmpty { Text(order.cancelReason).font(.callout) }
            if canRespond {
                HStack {
                    Button("Accept") { respondCancel(accept: true) }
                        .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                    Button("Decline") { respondCancel(accept: false) }
                        .buttonStyle(GlassOutlineButtonStyle())
                }
                .disabled(isWorking)
                Button("Escalate to Admin") { onAction(.escalate) }
                    .font(.subheadline.weight(.semibold))
            } else {
                note("Waiting for the other side to respond.")
            }
        }
    }

    // MARK: Helpers

    private func respondCancel(accept: Bool) {
        run { try await OrderService.respondToCancel(order, accept: accept, session: session) }
    }

    private func respondExtension(_ days: Int, accept: Bool) {
        run { try await OrderService.respondToExtension(order, days: days, accept: accept, session: session) }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        isWorking = true
        Task {
            do { try await work() } catch { errorMessage = error.friendlyMessage }
            isWorking = false
        }
    }

    private func actionButton(_ action: OrderAction, prominent: Bool = true, title: String? = nil) -> some View {
        Button {
            onAction(action)
        } label: {
            Label(title ?? action.title, systemImage: action.icon)
        }
        .buttonStyle(GlassOutlineButtonStyle(prominent: prominent))
    }

    private func box<Content: View>(tint: Color = .white, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(tint == .white ? 0.06 : 0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func note(_ text: String) -> some View {
        Label(text, systemImage: "info.circle").font(.callout).foregroundStyle(.secondary)
    }

    /// "2d 4h 10m 05s"
    static func countdown(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return String(format: "%dd %dh %dm %02ds", s / 86_400, (s % 86_400) / 3_600, (s % 3_600) / 60, s % 60)
    }
}
