with open('lib/screens/chat_screen.dart', 'r') as f:
    content = f.read()

# 1. Add _isFreelancer to state
content = content.replace("  late String _chatId;", "  late String _chatId;\n  bool _isFreelancer = false;")

# 2. Update _initializeChat
old_init = """  Future<void> _initializeChat() async {
    final auth = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final currentUser = auth.user;
    
    if (currentUser == null) return;

    if (_chatId.isEmpty || _chatId == 'new') {
      _chatId = await chatProvider.getOrCreateConversation(
        currentUserId: currentUser.uid,
        currentUserName: auth.displayName ?? '',
        currentUserAvatar: auth.photoUrl ?? '',
        targetUserId: widget.targetUserId,
        targetUserName: widget.targetUserName,
        targetUserAvatar: widget.targetUserAvatar,
      );
      if (mounted) setState(() {});
    }

    // Mark as read when entering
    await chatProvider.markAsRead(_chatId, currentUser.uid);
  }"""

new_init = """  Future<void> _initializeChat() async {
    final auth = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final currentUser = auth.user;
    
    if (currentUser == null) return;

    if (_chatId.isEmpty || _chatId == 'new') {
      _chatId = await chatProvider.getOrCreateConversation(
        currentUserId: currentUser.uid,
        currentUserName: auth.displayName ?? '',
        currentUserAvatar: auth.photoUrl ?? '',
        targetUserId: widget.targetUserId,
        targetUserName: widget.targetUserName,
        targetUserAvatar: widget.targetUserAvatar,
      );
      _isFreelancer = false;
      if (mounted) setState(() {});
    } else {
      final chat = await chatProvider.getConversation(_chatId);
      if (chat != null && mounted) {
        setState(() {
          _isFreelancer = chat.freelancerId == currentUser.uid;
        });
      }
    }

    // Mark as read when entering
    await chatProvider.markAsRead(_chatId, currentUser.uid);
  }"""

content = content.replace(old_init, new_init)

# 3. Update _buildMessageInput to conditionally show the offer button
old_button = """            IconButton(
              icon: const Icon(Icons.local_offer_outlined, color: AppTheme.primary),
              onPressed: _showCustomOfferModal,
              tooltip: 'Send Custom Offer',
            ),
            const SizedBox(width: 4),"""

new_button = """            if (_isFreelancer) ...[
              IconButton(
                icon: const Icon(Icons.local_offer_outlined, color: AppTheme.primary),
                onPressed: _showCustomOfferModal,
                tooltip: 'Send Custom Offer',
              ),
              const SizedBox(width: 4),
            ],"""

content = content.replace(old_button, new_button)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(content)
print("Updated chat_screen.dart")
