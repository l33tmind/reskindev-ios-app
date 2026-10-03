import SwiftUI

/// The open WorkStream: header, messages, quick replies, composer —
/// with the workspace details floating beside the window as an ornament
struct ChatView: View {
    @Environment(ChatStore.self) private var chat
    @Environment(SessionStore.self) private var session
    @State private var draft = ""
    @State private var replyTo: ChatMessage?
    @State private var showOffer = false
    @State private var showWorkspace = true
    @State private var showReport = false
    @State private var sheetAction: OrderAction?
    @State private var toast: String?
    @State private var errorMessage: String?
    @FocusState private var composerFocused: Bool

    var body: some View {
        if let conversation = chat.activeChat, let uid = session.uid {
            VStack(spacing: 0) {
                header(conversation, me: uid)
                messageList(me: uid, conversation: conversation)
                if session.isBlockedByAdmin {
                    Label("Your account is suspended by Reskindev, so messaging is disabled.", systemImage: "exclamationmark.octagon.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding(20)
                } else if chat.isBlocked {
                    Label("Messaging is unavailable: one of you has blocked the other.", systemImage: "hand.raised.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(20)
                } else {
                    composer
                }
            }
            .overlay(alignment: .top) {
                if let toast {
                    Label(toast, systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .glassBackgroundEffect(in: Capsule())
                        .padding(.top, 100)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .ornament(visibility: showWorkspace ? .visible : .hidden,
                      attachmentAnchor: .scene(.trailing), contentAlignment: .leading) {
                WorkspacePanel(onAction: { sheetAction = $0 })
                    // Turned in toward the viewer, hinged on the edge next to the chat, so it's easy to read
                    .rotation3DEffect(.degrees(-24), axis: (x: 0, y: 1, z: 0), anchor: .leading)
                    .padding(.leading, 20)
            }
            .sheet(item: $sheetAction) { action in
                if let order = chat.currentOrder {
                    OrderActionSheet(order: order, action: action) { show($0) }
                }
            }
            .sheet(isPresented: $showOffer) { OfferComposer() }
            .alert("Report user", isPresented: $showReport) {
                ReportButtons { reason in
                    Task {
                        do { try await chat.report(reason: reason); show("Report submitted successfully") }
                        catch { errorMessage = error.localizedDescription }
                    }
                }
            } message: {
                Text("Why are you reporting this user?")
            }
            .errorAlert("Something went wrong", message: $errorMessage)
            .task(id: chat.chatOrders.map(\.status)) {
                await OrderService.applyAutomaticRules(to: chat.chatOrders, session: session)
            }
        }
    }

    // MARK: Header ("WorkStream with …")

    private func header(_ conversation: Conversation, me: String) -> some View {
        let order = chat.currentOrder
        let name = chat.otherUser?.name ?? conversation.title(me: me)
        return HStack(alignment: .center, spacing: 16) {
            UserAvatar(name: name, photoUrl: chat.photo(for: conversation.otherID(me: me)), size: 52)
            VStack(alignment: .leading, spacing: 4) {
                (Text("WorkStream with ").foregroundStyle(.secondary) + Text(name).bold())
                    .font(.title3)
                if let order {
                    Text(order.gigTitle).font(.headline).foregroundStyle(Color.brandGreen).lineLimit(1)
                } else {
                    let online = chat.otherUser?.isOnline ?? false
                    Label(online ? "Online" : "Offline", systemImage: "circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(online ? Color.green : Color.secondary)
                        .labelStyle(DotLabelStyle())
                }
            }
            Spacer()

            if chat.amISeller, let order, order.isInProgress {
                Button { sheetAction = .deliver } label: { Label("Deliver Order", systemImage: "shippingbox.fill") }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brandGreen)
            }
            if chat.amISeller || session.canSell {
                Button { showOffer = true } label: { Label("Create Offer", systemImage: "briefcase") }
                    .buttonStyle(.bordered)
            }
            Button {
                withAnimation { showWorkspace.toggle() }
            } label: {
                Label("Workspace", systemImage: "sidebar.trailing")
            }
            .buttonStyle(.bordered)
            .help("Show or hide workspace details")

            Menu {
                if let order, order.isCancellable || order.isDelivered {
                    Section("Resolution Center") {
                        Button { sheetAction = .cancel } label: { Label("Request Cancellation", systemImage: "xmark.octagon") }
                        Button { sheetAction = .escalate } label: { Label("Escalate to Admin", systemImage: "exclamationmark.shield") }
                    }
                }
                Button {
                    Task {
                        do { try await chat.toggleBlock() } catch { errorMessage = error.localizedDescription }
                    }
                } label: {
                    let blocked = conversation.otherID(me: me).map { chat.blockedByMe.contains($0) } ?? false
                    Label(blocked ? "Unblock User" : "Block User", systemImage: "hand.raised")
                }
                Button(role: .destructive) { showReport = true } label: { Label("Report User", systemImage: "flag") }
            } label: {
                Image(systemName: "ellipsis.circle").font(.title2)
                    .frame(width: Hit.min, height: Hit.min)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More options")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05))
    }

    // MARK: Messages

    private func messageList(me: String, conversation: Conversation) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if chat.messagesLoading && chat.messages.isEmpty {
                        ProgressView().padding(40)
                    }
                    ForEach(chat.messages) { message in
                        MessageRow(message: message, me: me, conversation: conversation,
                                   onReply: { replyTo = $0; composerFocused = true },
                                   onAction: { sheetAction = $0 },
                                   onError: { errorMessage = $0 })
                            .id(message.id)
                    }
                    if conversation.isOtherTyping(me: me) {
                        HStack {
                            Text("\(chat.otherUser?.name ?? conversation.title(me: me)) is typing…")
                                .font(.subheadline.italic())
                                .foregroundStyle(Color.brandGreen)
                            Spacer()
                        }
                    }
                }
                .padding(24)
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: chat.messages.last?.id) {
                withAnimation { proxy.scrollTo(chat.messages.last?.id, anchor: .bottom) }
            }
        }
    }

    // MARK: Composer + quick replies

    private var composer: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chat.quickReplies, id: \.self) { reply in
                        Button(reply) { draft = reply; composerFocused = true }
                            .font(.subheadline)
                            .buttonStyle(.bordered)
                    }
                }
            }

            if let replyTo {
                HStack {
                    Label("Replying to: \(replyTo.text)", systemImage: "arrowshape.turn.up.left")
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button { self.replyTo = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Cancel reply")
                }
            }

            HStack(spacing: 12) {
                TextField("Type a message…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($composerFocused)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
                    .onChange(of: draft) { _, new in if !new.isEmpty { chat.userTyped() } }
                    .onSubmit(send)
                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: Hit.min, height: Hit.min)
                        .background(Color.brandGreen, in: Circle())
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
                .disabled(draft.trimmed.isEmpty)
                .accessibilityLabel("Send")
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private func send() {
        let text = draft.trimmed
        guard !text.isEmpty else { return }
        let reply = replyTo
        draft = ""
        replyTo = nil
        Task {
            do { try await chat.send(text: text, replyTo: reply) } catch {
                draft = text
                errorMessage = error.localizedDescription
            }
        }
    }

    private func show(_ message: String) {
        withAnimation { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { toast = nil }
        }
    }
}

/// "● Online"
private struct DotLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.caption2)
            configuration.title
        }
    }
}

private struct ReportButtons: View {
    let onReport: (String) -> Void
    var body: some View {
        ForEach(["Spam", "Harassment", "Scam or fraud", "Off-platform payment"], id: \.self) { reason in
            Button(reason) { onReport(reason) }
        }
        Button("Cancel", role: .cancel) { }
    }
}

// MARK: - Workspace Details (website right sidebar), floating beside the Inbox window

private struct WorkspacePanel: View {
    var onAction: (OrderAction) -> Void
    @Environment(ChatStore.self) private var chat
    @Environment(SessionStore.self) private var session

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Workspace Details").font(.title2.weight(.heavy))
                if let uid = session.uid, let conversation = chat.activeChat {
                    let name = chat.otherUser?.name ?? conversation.title(me: uid)
                    HStack(spacing: 12) {
                        UserAvatar(name: name, photoUrl: chat.photo(for: conversation.otherID(me: uid)), size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name).font(.headline)
                            Text(chat.amISeller ? "BUYER" : "SELLER")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                // Several orders between the same two people: pick one
                if chat.chatOrders.count > 1, chat.activeChat?.orderId == nil {
                    Text("\(chat.chatOrders.count) orders together · showing the latest")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)

            Divider()

            ScrollView {
                if let order = chat.currentOrder {
                    WorkspaceTimeline(order: order, onAction: onAction)
                        .padding(24)
                } else {
                    ContentUnavailableView("No active order", systemImage: "briefcase",
                                           description: Text("Start an order to see details here."))
                        .padding(.vertical, 60)
                }
            }
        }
        .frame(width: 400, height: 640)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Radius.large))
    }
}

// MARK: - Custom offer (seller → buyer)

private struct OfferComposer: View {
    @Environment(ChatStore.self) private var chat
    @Environment(\.dismiss) private var dismiss
    @State private var price = ""
    @State private var days = ""
    @State private var description = ""
    @State private var sending = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Create Custom Offer").font(.title.weight(.bold))
            GlassField(title: "Price (USD)", text: $price, prompt: "150")
            GlassField(title: "Delivery days", text: $days, prompt: "5")
            GlassField(title: "What's included", text: $description, axis: .vertical)
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(GlassOutlineButtonStyle())
                Button {
                    Task {
                        sending = true
                        do {
                            try await chat.sendOffer(price: Double(price) ?? 0, days: Int(days) ?? 3, description: description)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                        sending = false
                    }
                } label: {
                    if sending { ProgressView() } else { Text("Send Offer") }
                }
                .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                .disabled((Double(price) ?? 0) <= 0 || (Int(days) ?? 0) <= 0 || sending)
            }
        }
        .padding(32)
        .frame(width: 520)
        .errorAlert("Couldn't send offer", message: $errorMessage)
    }
}
