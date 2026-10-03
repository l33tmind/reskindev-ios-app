import SwiftUI

/// Inbox window: conversations on the left, the open chat on the right (website app/inbox/page.js)
struct InboxView: View {
    @Environment(ChatStore.self) private var chat
    @Environment(SessionStore.self) private var session
    @State private var showSignIn = false
    @State private var search = ""

    private var filtered: [Conversation] {
        guard let uid = session.uid else { return [] }
        let q = search.trimmed.lowercased()
        guard !q.isEmpty else { return chat.conversations }
        return chat.conversations.filter {
            $0.title(me: uid).lowercased().contains(q) || ($0.gigTitle ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        @Bindable var chat = chat

        Group {
            if let uid = session.uid {
                NavigationSplitView {
                    Group {
                        if chat.conversationsLoading && chat.conversations.isEmpty {
                            ProgressView()
                        } else if chat.conversations.isEmpty {
                            ContentUnavailableView("No messages yet", systemImage: "tray",
                                                   description: Text("Contact a seller from any service to start a chat."))
                        } else {
                            List(filtered, selection: $chat.activeChatID) { conversation in
                                ConversationRow(conversation: conversation, me: uid)
                                    .tag(conversation.id)
                            }
                            .searchable(text: $search, prompt: "Search chats")
                        }
                    }
                    .navigationTitle("Inbox")
                    .navigationSplitViewColumnWidth(min: 300, ideal: 340)
                } detail: {
                    if chat.activeChat != nil {
                        ChatView()
                    } else {
                        ContentUnavailableView("Select a conversation", systemImage: "bubble.left.and.bubble.right")
                    }
                }
                .onAppear {
                    if chat.activeChatID == nil { chat.activeChatID = chat.conversations.first?.id }
                }
            } else {
                ContentUnavailableView {
                    Label("Sign in to see your messages", systemImage: "tray")
                } actions: {
                    Button("Sign In") { showSignIn = true }
                        .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                        .frame(width: 220)
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 640)
        .sheet(isPresented: $showSignIn) { SignInView() }
    }
}

private struct ConversationRow: View {
    let conversation: Conversation
    let me: String
    @Environment(ChatStore.self) private var chat

    var body: some View {
        let unread = conversation.unreadCount(for: me)
        HStack(spacing: 14) {
            UserAvatar(name: conversation.title(me: me), photoUrl: chat.photo(for: conversation.otherID(me: me)), size: 46)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.title(me: me))
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    if let date = conversation.updatedAt {
                        Text(date, format: .relative(presentation: .numeric, unitsStyle: .abbreviated))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if conversation.orderId != nil {
                    Label(conversation.gigTitle ?? "Order", systemImage: "shippingbox")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brandGreen)
                        .lineLimit(1)
                }
                HStack {
                    Text(conversation.isOtherTyping(me: me) ? "typing…" : conversation.lastMessage)
                        .font(.subheadline)
                        .foregroundStyle(conversation.isOtherTyping(me: me) ? Color.brandGreen : .secondary)
                        .lineLimit(1)
                    Spacer()
                    if unread > 0 {
                        Text("\(unread)")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.brandGreen, in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
