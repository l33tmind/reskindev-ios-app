import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    content = f.read()

# 1. Update _initializeChat
old_init = """    if (_chatId.isEmpty || _chatId == 'new') {
      _chatId = await chatProvider.getOrCreateConversation(
        currentUserId: currentUser.uid,
        currentUserName: auth.displayName,
        currentUserAvatar: auth.photoUrl,
        targetUserId: widget.targetUserId,
        targetUserName: widget.targetUserName,
        targetUserAvatar: widget.targetUserAvatar,
      );
      if (mounted) setState(() {});
    }

    // Mark as read when entering
    await chatProvider.markAsRead(_chatId, currentUser.uid);"""

new_init = """    if (_chatId.isEmpty || _chatId == 'new') {
      _chatId = await chatProvider.getOrCreateConversation(
        currentUserId: currentUser.uid,
        currentUserName: auth.displayName,
        currentUserAvatar: auth.photoUrl,
        targetUserId: widget.targetUserId,
        targetUserName: widget.targetUserName,
        targetUserAvatar: widget.targetUserAvatar,
      );
    }
    
    if (mounted) {
      setState(() {
        _messagesStream = context.read<ChatProvider>().getMessages(_chatId, limit: _messageLimit);
      });
    }

    // Mark as read when entering
    await chatProvider.markAsRead(_chatId, currentUser.uid);"""
content = content.replace(old_init, new_init)

# 2. Change initial limit to 20
content = content.replace('int _messageLimit = 30;', 'int _messageLimit = 20;')

# 3. Remove auto-pagination from _onScroll
old_scroll = """  void _onScroll() {
    // With reverse: true, scrolling UP (older messages) increases pixels towards maxScrollExtent
    if (_scrollController.hasClients && _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 20) {
      if (_messageLimit < 500) { // arbitrary max
        setState(() {
          _messageLimit += 30;
          _messagesStream = context.read<ChatProvider>().getMessages(_chatId, limit: _messageLimit);
        });
      }
    }
  }"""

new_scroll = """  void _onScroll() {
    // Auto pagination removed as per user request for "Show More" button.
  }"""
content = content.replace(old_scroll, new_scroll)

# 4. Add "Show More" button to ListView
old_listview = """                      return ListView.builder(
                        reverse: true,
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {"""

new_listview = """                      return ListView.builder(
                        reverse: true,
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount: messages.length + (messages.length >= _messageLimit ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == messages.length) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _messageLimit += 20;
                                      _messagesStream = context.read<ChatProvider>().getMessages(_chatId, limit: _messageLimit);
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  child: Text('Load More Messages', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                ),
                              ),
                            );
                          }
                          """
content = content.replace(old_listview, new_listview)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(content)

print("Fixed chat screen initialization and added Load More button")
