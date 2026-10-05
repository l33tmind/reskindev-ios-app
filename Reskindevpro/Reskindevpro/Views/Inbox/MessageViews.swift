import SwiftUI

/// One message: text bubble, system card or custom offer card
struct MessageRow: View {
    let message: ChatMessage
    let me: String
    let conversation: Conversation
    var onReply: (ChatMessage) -> Void = { _ in }
    var onAction: (OrderAction) -> Void = { _ in }
    var onError: (String) -> Void = { _ in }
    @Environment(ChatStore.self) private var chat

    var body: some View {
        switch message.kind {
        case .system:
            SystemCard(message: message, me: me, chatID: conversation.id, onAction: onAction, onError: onError)
        case .offer:
            OfferCard(message: message, isMine: message.senderId == me, conversation: conversation, onError: onError)
        case .text:
            TextBubble(message: message, isMine: message.senderId == me,
                       avatar: message.senderId == me ? "" : chat.photo(for: message.senderId),
                       senderName: message.senderName.isEmpty ? conversation.title(me: me) : message.senderName)
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
    var avatar: String = ""
    var senderName: String = ""

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if isMine { Spacer(minLength: 120) }
            if !isMine {
                UserAvatar(name: senderName, photoUrl: avatar, size: 34)
                    .accessibilityHidden(true)
            }
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
            .background(isMine ? AnyShapeStyle(Color.brandGreen.opacity(0.8)) : AnyShapeStyle(Color.white.opacity(0.1)),
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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

    /// Who's reading: from the order if we have it, else from the chat (website isThisBuyer / isThisSeller)
    private var role: CardCopy.Role {
        if let order {
            if order.isBuyer(me) { return .buyer }
            if order.isSeller(me) { return .seller }
        }
        if chat.activeChat?.clientId == me { return .buyer }
        if chat.activeChat?.freelancerId == me { return .seller }
        return chat.amISeller ? .seller : .buyer
    }

    /// One accent per kind of event, so a card reads at a glance
    private var tone: Color {
        switch message.actionType {
        case "order_placed": .orange
        case "order_delivered": .purple
        case "requirements_submitted", "extension_requested", "extension_accepted": .blue
        case "revision_requested", "escalated_to_admin", "dispute_opened": Color(red: 1, green: 0.58, blue: 0.2)
        case "cancel_requested", "cancel_accepted": .red
        case "cancel_declined", "extension_declined": .gray
        default: Color.brandGreen
        }
    }

    private var showsOrderFacts: Bool {
        message.actionType == "order_placed" || message.actionType == "payment_verified"
    }

    var body: some View {
        let style = message.systemStyle
        let copy = CardCopy(message: message, order: order, role: role, me: me)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                header(style: style, copy: copy)

                // The same event reads differently for the buyer and the seller
                if copy.title != nil || copy.body != nil {
                    callout(copy)
                } else if !message.text.isEmpty && message.actionType != "order_delivered" {
                    Text(message.text).font(.body).foregroundStyle(.secondary).textSelection(.enabled)
                }
                if showsOrderFacts { facts }
                if let quote = copy.quote {
                    Text("“\(quote)”")
                        .font(.body).italic().foregroundStyle(.secondary).textSelection(.enabled)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                if !message.deliveryMessage.isEmpty {
                    Text(message.deliveryMessage).font(.body).textSelection(.enabled)
                }
                if let url = URL(string: message.deliveryLink), !message.deliveryLink.isEmpty {
                    HStack(spacing: 12) {
                        if let orderID = message.orderId {
                            TheaterButton(item: TheaterItem(orderID: orderID, title: message.gigTitle,
                                                            link: message.deliveryLink, message: message.deliveryMessage),
                                          prominent: true)
                        }
                        Link(destination: url) {
                            Label("Open delivered files", systemImage: "arrow.up.right.square")
                        }
                        .font(.headline)
                    }
                }
                if !message.cancelReason.isEmpty {
                    Text("Reason: \(message.cancelReason)").font(.subheadline).foregroundStyle(.secondary)
                }
                if message.actionType == "order_completed" { reviewContent }

                actions
                    .disabled(isWorking)

                if message.price > 0 && !showsOrderFacts { amountRow }
            }
            .padding(22)

            if let next = copy.next { footer(next) }
        }
        .frame(maxWidth: 620, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func header(style: (title: String, icon: String), copy: CardCopy) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: style.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tone)
                .frame(width: 42, height: 42)
                .background(tone.opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(message.actionType == "text" ? "Reskindev" : style.title)
                    .font(.headline)
                if let date = message.createdAt {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            Spacer(minLength: 8)
            if !message.gigTitle.isEmpty {
                Text(message.gigTitle)
                    .font(.subheadline.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .frame(maxWidth: 220)
            }
        }
    }

    /// Tinted message block: headline + one calm paragraph
    private func callout(_ copy: CardCopy) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = copy.title {
                Text(title).font(.title3.weight(.semibold)).foregroundStyle(tone)
            }
            if let body = copy.body {
                Text(body).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(tone.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Order # / amount / start / duration, like the website's tiles
    private var facts: some View {
        let isPlaced = message.actionType == "order_placed"
        let id = String((message.orderId ?? "").suffix(6)).uppercased()
        return HStack(spacing: 10) {
            fact("Order #", id.isEmpty ? "—" : "#\(id)")
            fact(isPlaced ? "Pending" : "Escrow", (order?.price ?? message.price).usd, tint: tone)
            fact("Start", (message.createdAt ?? .now).formatted(.dateTime.day().month(.abbreviated)))
            if let days = order?.deliveryDays { fact("Duration", "\(days) \(days == 1 ? "Day" : "Days")") }
        }
    }

    private func fact(_ label: String, _ value: String, tint: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold)).tracking(0.8)
                .foregroundStyle(tint ?? .secondary)
            Text(value)
                .font(.system(.body, design: .rounded).weight(.semibold)).monospacedDigit()
                .foregroundStyle(tint ?? .primary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background((tint ?? .white).opacity(tint == nil ? 0.06 : 0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var amountRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(message.actionType == "order_completed" ? "FINAL AMOUNT PAID" : "AMOUNT")
                .font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(.secondary)
            Spacer()
            Text(message.price.usd)
                .font(.system(.title, design: .rounded).weight(.semibold)).monospacedDigit()
            if message.actionType == "order_completed" {
                Label("Cleared", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(Color.brandGreen)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.brandGreen.opacity(0.15), in: Capsule())
            }
        }
        .padding(.top, 4)
    }

    /// "What's next: …" with the lead-in in bold
    private func footer(_ text: String) -> some View {
        let lead = "What's next:"
        let rest = text.hasPrefix(lead) ? String(text.dropFirst(lead.count)) : " " + text
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(.secondary)
            (Text(text.hasPrefix(lead) ? lead : "").fontWeight(.semibold) + Text(rest))
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22).padding(.vertical, 14)
        .background(Color.black.opacity(0.12))
        .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1) }
    }

    @ViewBuilder
    private var reviewContent: some View {
        if message.isReviewPublic, let rating = message.rating, rating > 0 {
            VStack(alignment: .leading, spacing: 16) {
                review(rating: rating, label: "Buyer", comment: message.comment)
                if let sellerRating = message.sellerRating {
                    Divider().overlay(Color.white.opacity(0.08))
                    review(rating: Int(sellerRating.rounded()), label: "Seller", comment: message.sellerComment)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else if message.comment == "Hidden review" {
            Label("Review hidden until both sides have reviewed.", systemImage: "lock.fill")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func review(rating: Int, label: String, comment: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            stars(rating, label: label)
            if !comment.isEmpty { Text("“\(comment)”").font(.body).foregroundStyle(.secondary) }
        }
    }

    /// Buttons the website shows inside the card, only while they still apply
    @ViewBuilder
    private var actions: some View {
        if let order {
            switch message.actionType {
            case "payment_verified":
                if order.needsRequirements && order.isBuyer(me) {
                    cardButton("Submit Requirements", prominent: true) { onAction(.requirements) }
                }
            case "requirements_submitted", "revision_requested":
                if order.isInProgress && order.isSeller(me) {
                    cardButton(order.status == "revision" ? "Deliver Revision" : "Deliver Work", prominent: true) { onAction(.deliver) }
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
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(prominent ? Color.brandGreen : nil)
    }

    private func stars(_ rating: Int, label: String) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < rating ? "star.fill" : "star").font(.subheadline).foregroundStyle(Color.starYellow)
            }
            Text(String(format: "%.1f", Double(rating))).font(.subheadline.weight(.semibold)).monospacedDigit().padding(.leading, 6)
            Text(label.uppercased())
                .font(.caption2.weight(.semibold)).tracking(0.6).foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.white.opacity(0.08), in: Capsule())
                .padding(.leading, 4)
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
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.brandGreen)
                        .frame(width: 36, height: 36)
                        .background(Color.brandGreen.opacity(0.18), in: Circle())
                    Text("Custom Offer").font(.headline)
                    Spacer()
                    Text(message.offerPrice.usd)
                        .font(.system(.title, design: .rounded).weight(.semibold)).monospacedDigit()
                }
                if !message.offerDescription.isEmpty {
                    Text(message.offerDescription).font(.body).foregroundStyle(.secondary)
                }
                HStack {
                    Label("\(message.offerDays) days delivery", systemImage: "clock")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    if message.offerStatus == "accepted" {
                        Label("Accepted", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(Color.brandGreen)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.brandGreen.opacity(0.15), in: Capsule())
                    } else if isMine {
                        Text("Waiting for the buyer")
                            .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                    }
                }
                if message.offerStatus != "accepted" && !isMine {
                    Button {
                        accept()
                    } label: {
                        if accepting { ProgressView() } else { Text("Accept Offer") }
                    }
                    .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                    .disabled(accepting)
                }
            }
            .padding(22)
            .frame(width: 380)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
            if !isMine { Spacer(minLength: 120) }
        }
        // Same as the website: Accept Offer opens a checkout (fee, payment, contact, requirements)
        .sheet(isPresented: $showCheckout) { CheckoutView(offer: message, in: conversation).sheetPresence() }
    }

    private func accept() { showCheckout = true }
}

// MARK: - Role-specific card text (website inbox "PPH style" cards)

/// What a system card says to the buyer vs. the seller, plus the "What's next" line
private struct CardCopy {
    enum Role { case buyer, seller }

    var title: String?
    var body: String?
    var quote: String?
    var next: String?

    init(message: ChatMessage, order: OrderModel?, role: Role, me: String) {
        let buyer = role == .buyer
        let amount = (order?.price ?? message.price).usd
        switch message.actionType {
        case "order_placed":
            title = buyer ? "Order Placed! ⏳" : "New Order! ⏳"
            body = buyer
                ? "Your order has been created. Please wait while Reskindev verifies your payment. Once verified, the funds are secured in escrow."
                : "The buyer has placed a new order. The payment is pending verification by Reskindev — please wait for it to be secured before starting work."
            next = "What's next: Reskindev verifies the payment."
        case "payment_verified":
            title = buyer ? "Payment Secured! 🎉" : "Great news! 🎉"
            body = buyer
                ? "Your payment of \(amount) has been verified and secured in escrow. Submit your project requirements to start the countdown."
                : "The buyer funded \(amount) into escrow. You can begin as soon as they submit the requirements."
            next = "What's next: the buyer submits requirements to start the timer."
        case "requirements_submitted":
            title = buyer ? "Requirements Sent" : "Requirements Received"
            body = buyer ? "Here's a reminder of what you asked for:" : "The buyer's requirements:"
            quote = message.text.isEmpty ? nil : message.text
            next = buyer
                ? "What's next: the countdown has started. The seller is now working on your project."
                : "What's next: the countdown has started. You can begin working on the order."
        case "order_delivered":
            title = buyer ? "Delivery Received! 📦" : "Work Delivered ✅"
            body = buyer
                ? "The seller delivered your order. Review it, then accept or ask for changes."
                : "You delivered the order. Waiting for the buyer to review it."
            next = buyer ? "Accepting completes the order. It auto-completes after 3 days." : nil
        case "revision_requested":
            title = buyer ? "Revision Requested" : "Changes Requested"
            body = buyer ? "You asked the seller for changes. They're working on it." : "The buyer asked for changes:"
            quote = buyer ? nil : message.text.replacingOccurrences(of: "Revision requested: ", with: "")
        case "order_completed" where !message.isReviewPublic:
            title = buyer ? "Order Completed 🎉" : "Delivery Accepted! 🎉"
            body = buyer
                ? "You accepted the delivery. Your review stays hidden until the seller reviews you back."
                : "The buyer accepted your delivery! Rate the buyer to see their review — both go public together."
        case "cancel_requested":
            let mine = message.requestedBy == me
            title = mine ? "You asked to cancel" : (buyer ? "The seller asked to cancel" : "The buyer asked to cancel")
            body = mine ? "Waiting for the other side to respond." : nil
        case "extension_requested":
            title = buyer ? "The seller needs more time" : "You asked for more time"
            body = buyer ? "Extra days: \(message.extensionDays)" : "Waiting for the buyer to respond."
            quote = message.text.isEmpty ? nil : message.text
        default:
            break
        }
    }
}
