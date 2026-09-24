import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    content = f.read()

# 1. Add state variable
if "MessageModel? _replyingTo;" not in content:
    content = content.replace("  final ScrollController _scrollController = ScrollController();", "  final ScrollController _scrollController = ScrollController();\n  MessageModel? _replyingTo;")

# 2. Add Quick Replies above input
old_input_call = """              return _buildMessageInput();"""
new_input_call = """              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildQuickReplies(auth),
                  if (_replyingTo != null) _buildReplyPreview(),
                  _buildMessageInput(),
                ],
              );"""
content = content.replace(old_input_call, new_input_call)

# 3. Modify _sendMessage to send reply fields and clear _replyingTo
old_send = """    chatProvider.sendMessage(
      chatId: _chatId,
      currentUserId: currentUser.uid,
      currentUserName: auth.user?.displayName ?? 'User',
      targetUserId: widget.targetUserId,
      text: _controller.text.trim(),
    );

    _controller.clear();"""
new_send = """    chatProvider.sendMessage(
      chatId: _chatId,
      currentUserId: currentUser.uid,
      currentUserName: auth.user?.displayName ?? 'User',
      targetUserId: widget.targetUserId,
      text: _controller.text.trim(),
      replyToId: _replyingTo?.id,
      replyToText: _replyingTo?.text,
      replyToSender: _replyingTo?.senderName,
    );

    _controller.clear();
    setState(() { _replyingTo = null; });"""
content = content.replace(old_send, new_send)

# 4. Add _buildReplyPreview and _buildQuickReplies methods
methods = """
  Widget _buildQuickReplies(AuthProvider auth) {
    if (!auth.isFreelancer) return const SizedBox.shrink();
    
    final templates = [
      "Hello! How can I help you?",
      "Let me check the details.",
      "Thanks for ordering!",
      "I'll deliver this soon.",
      "Could you provide more info?",
    ];
    
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: templates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(templates[index], style: const TextStyle(fontSize: 12)),
            backgroundColor: context.themeSurface,
            side: BorderSide(color: context.themeBorder),
            onPressed: () {
              _controller.text = templates[index];
              _sendMessage();
            },
          );
        },
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: context.themeSurface.withValues(alpha: 0.5),
      child: Row(
        children: [
          Container(width: 4, height: 40, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _replyingTo!.senderName,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary),
                ),
                Text(
                  _replyingTo!.text,
                  style: GoogleFonts.inter(fontSize: 12, color: context.themeTextDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }
"""
if "_buildReplyPreview" not in content:
    content = content.replace("  Widget _buildMessageInput() {", methods + "\n  Widget _buildMessageInput() {")

# 5. Wrap ChatBubble in Dismissible
old_bubble = """                          Widget bubble = ChatBubble(
                            message: msg, 
                            isMe: isMe,
                            isFirstInGroup: isFirst,
                            isLastInGroup: isLast,
                            isRead: isRead,
                          );"""
new_bubble = """                          Widget bubble = Dismissible(
                            key: Key(msg.id.isNotEmpty ? msg.id : UniqueKey().toString()),
                            direction: DismissDirection.startToEnd,
                            confirmDismiss: (direction) async {
                              setState(() => _replyingTo = msg);
                              return false; // Don't actually dismiss
                            },
                            background: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              color: Colors.transparent,
                              child: const Icon(Icons.reply, color: Colors.grey),
                            ),
                            child: ChatBubble(
                              message: msg, 
                              isMe: isMe,
                              isFirstInGroup: isFirst,
                              isLastInGroup: isLast,
                              isRead: isRead,
                            ),
                          );"""
content = content.replace(old_bubble, new_bubble)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(content)

print("Added swipe-to-reply and quick replies to chat_screen")
