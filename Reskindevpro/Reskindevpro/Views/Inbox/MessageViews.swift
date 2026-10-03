import SwiftUI

/// One message: text bubble, system card or custom offer card
struct MessageRow: View {
    let message: ChatMessage
    let me: String
    let conversation: Conversation
    var onReply: (ChatMessage) -> Void = { _ in }
    var onAction: (OrderAction) -> Void = { _ in }
    var onError: (String) -> Void = { _ in }

    var body: some View {
        switch message.kind {
        case .system:
            SystemCard(message: message, me: me, chatID: conversation.id, onAction: onAction, onError: onError)
        case .offer:
            OfferCard(message: message, isMine: message.senderId == me, conversation: conversation, onError: onError)
        case .text:
            TextBubble(message: message, isMine: message.senderId == me)
                .contextMenu {
                    Button { onReply(message) } label: { Label("Reply", systemImage: "arrowshape.turn.up.left") }
                    Button { UIPasteboard.general.string = message.text } label: { Label("Copy", systemImage: "doc.on.doc") }
                }
        }
    }
}

// MARK: - Text bubble

private struct TextBubble: View {
    let message: ChatMessage
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 120) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
                if let reply = message.replyToText {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(message.replyToSender ?? "").font(.caption.weight(.bold))
                        Text(reply).font(.caption).lineLimit(2)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                }
                if let image = message.gigImage {
                    CachedImage(url: image)
                        .frame(width: 260, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Text(linkified(message.text))
                    .font(.body)
                    .textSelection(.enabled)
                if let date = message.createdAt {
                    Text(date.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isMine ? AnyShapeStyle(Color.brandGreen.opacity(0.75)) : AnyShapeStyle(Color.white.opacity(0.1)),
                        in: RoundedRectangle(cornerRadius: 20))
            if !isMine { Spacer(minLength: 120) }
        }
        .accessibilityElement(children: .combine)
    }

    /// Makes https:// links in messages tappable
    private func linkified(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return result }
        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text), let url = match.url,
                  let attrRange = Range(range, in: result) else { continue }
            result[attrRange].link = url
            result[attrRange].underlineStyle = .single
        }
        return result
    }
}

// MARK: - System card (order events, with the website's in-chat buttons)

private struct SystemCard: View {
    let message: ChatMessage
    let me: String
    let chatID: String
    var onAction: (OrderAction) -> Void
    var onError: (String) -> Void

    @Environment(ChatStore.self) private var chat
    @Environment(SessionStore.self) private var session
    @State private var isWorking = false

    /// Live order this card is about
    private var order: OrderModel? {
        guard let id = message.orderId else { return nil }
        return chat.chatOrders.first { $0.id == id } ?? session.order(id: id)
    }

    var body: some View {
        let style = message.systemStyle
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: style.icon)
                    .font(.title2)
                    .foregroundStyle(Color.brandGreen)
                    .frame(width: 44, height: 44)
                    .background(Color.brandGreen.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(message.actionType == "text" ? "Reskindev" : style.title).font(.headline)
                    if !message.gigTitle.isEmpty {
                        Text(message.gigTitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                if message.price > 0 {
                    Text(message.price.usd).font(.title3.weight(.bold)).foregroundStyle(Color.brandGreen)
                }
            }

            if !message.text.isEmpty && message.actionType != "order_delivered" {
                Text(message.text).foregroundStyle(.secondary).textSelection(.enabled)
            }
            if !message.deliveryMessage.isEmpty {
                Text(message.deliveryMessage).textSelection(.enabled)
            }
            if let url = URL(string: message.deliveryLink), !message.deliveryLink.isEmpty {
                Link(destination: url) {
                    Label("Open delivered files", systemImage: "arrow.up.right.square")
                }
                .font(.headline)
            }
            if !message.cancelReason.isEmpty {
                Text("Reason: \(message.cancelReason)").foregroundStyle(.secondary)
            }
            if message.actionType == "order_completed" { reviewContent }

            actions
                .disabled(isWorking)
        }
        .padding(18)
        .frame(maxWidth: 620, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.brandGreen.opacity(0.35), lineWidth: 1))
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var reviewContent: some View {
        if message.isReviewPublic, let rating = message.rating, rating > 0 {
            stars(rating, label: "Buyer")
            if !message.comment.isEmpty { Text("“\(message.comment)”").italic().foregroundStyle(.secondary) }
            if let sellerRating = message.sellerRating {
                stars(Int(sellerRating.rounded()), label: "Seller")
                if !message.sellerComment.isEmpty { Text("“\(message.sellerComment)”").italic().foregroundStyle(.secondary) }
            }
        } else if message.comment == "Hidden review" {
            Label("Review hidden until both sides have reviewed.", systemImage: "lock.fill")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    /// Buttons the website shows inside the card, only while they still apply
    @ViewBuilder
    private var actions: some View {
        if let order {
            switch message.actionType {
            case "order_placed", "payment_verified":
                if order.needsRequirements && order.isBuyer(me) {
                    cardButton("Submit Requirements", prominent: true) { onAction(.requirements) }
                }
            case "order_delivered":
                if order.isDelivered && order.isBuyer(me) {
                    HStack {
                        cardButton("Accept Delivery", prominent: true) { onAction(.acceptDelivery) }
                        cardButton("Request Revision") { onAction(.revision) }
                    }
                }
            case "cancel_requested":
                if !message.actionResolved && order.isCancelRequested && message.requestedBy != me {
                    HStack {
                        cardButton("Accept Cancellation", prominent: true) { respondCancel(order, accept: true) }
                        cardButton("Decline") { respondCancel(order, accept: false) }
                        cardButton("Escalate") { onAction(.escalate) }
                    }
                }
            case "extension_requested":
                if !message.actionResolved, order.extensionRequest != nil, order.isBuyer(me) {
                    HStack {
                        cardButton("Accept +\(message.extensionDays) days", prominent: true) { respondExtension(order, accept: true) }
                        cardButton("Decline") { respondExtension(order, accept: false) }
                    }
                }
            case "order_completed":
                if order.isSeller(me) && order.sellerReview == nil && order.buyerReview != nil {
                    cardButton("Rate Buyer to Unlock Reviews", prominent: true) { onAction(.reviewBuyer) }
                }
            default:
                EmptyView()
            }
        }
    }

    private func respondCancel(_ order: OrderModel, accept: Bool) {
        run { try await OrderService.respondToCancel(order, accept: accept, session: session, messageID: message.id, chatID: chatID) }
    }

    private func respondExtension(_ order: OrderModel, accept: Bool) {
        let days = message.extensionDays > 0 ? message.extensionDays : (order.extensionRequest?.days ?? 1)
        run {
            try await OrderService.respondToExtension(order, days: days, accept: accept, session: session,
                                                      messageID: message.id, chatID: chatID)
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        isWorking = true
        Task {
            do { try await work() } catch { onError(error.localizedDescription) }
            isWorking = false
        }
    }

    private func cardButton(_ title: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(prominent ? Color.brandGreen : nil)
    }

    private func stars(_ rating: Int, label: String) -> some View {
        HStack(spacing: 2) {
            Text(label).font(.caption.weight(.bold)).foregroundStyle(.secondary).padding(.trailing, 6)
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < rating ? "star.fill" : "star").foregroundStyle(Color.starYellow)
            }
        }
    }
}

// MARK: - Custom offer card

private struct OfferCard: View {
    let message: ChatMessage
    let isMine: Bool
    let conversation: Conversation
    var onError: (String) -> Void

    @Environment(SessionStore.self) private var session
    @Environment(ChatStore.self) private var chat
    @State private var accepting = false
    @State private var showCheckout = false

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 120) }
            VStack(alignment: .leading, spacing: 12) {
                Label("Custom Offer", systemImage: "doc.badge.plus").font(.headline)
                HStack(alignment: .firstTextBaseline) {
                    Text(message.offerPrice.usd).font(.title.weight(.bold)).foregroundStyle(Color.brandGreen)
                    Spacer()
                    Label("\(message.offerDays) days", systemImage: "clock").foregroundStyle(.secondary)
                }
                if !message.offerDescription.isEmpty {
                    Text(message.offerDescription).foregroundStyle(.secondary)
                }
                if message.offerStatus == "accepted" {
                    Label("Accepted", systemImage: "checkmark.seal.fill").foregroundStyle(Color.brandGreen)
                } else if isMine {
                    Text("Waiting for the buyer to accept").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Button {
                        accept()
                    } label: {
                        if accepting { ProgressView() } else { Text("Accept Offer") }
                    }
                    .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                    .disabled(accepting)
                }
            }
            .padding(20)
            .frame(width: 380)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.medium))
            .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.brandGreen.opacity(0.5), lineWidth: 1.5))
            if !isMine { Spacer(minLength: 120) }
        }
        // Same as the website: Accept Offer opens a checkout (fee, payment, contact, requirements)
        .sheet(isPresented: $showCheckout) { CheckoutView(offer: message, in: conversation) }
    }

    private func accept() { showCheckout = true }
}
