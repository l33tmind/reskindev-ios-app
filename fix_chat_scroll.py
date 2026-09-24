import re

# 1. Update ChatProvider
with open('lib/providers/chat_provider.dart', 'r') as f:
    chat_prov = f.read()
chat_prov = chat_prov.replace(".orderBy('createdAt', descending: false)", ".orderBy('createdAt', descending: true)")
with open('lib/providers/chat_provider.dart', 'w') as f:
    f.write(chat_prov)

# 2. Update ChatScreen
with open('lib/screens/chat_screen.dart', 'r') as f:
    chat_screen = f.read()

# Remove animateTo on send
old_send = """    // Scroll to bottom
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }"""
new_send = """    // With reverse: true, we can optionally scroll to 0.0 (bottom) 
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }"""
chat_screen = chat_screen.replace(old_send, new_send)

# Fix scroll listener for reverse: true (bottom is minScrollExtent (0), top is maxScrollExtent)
old_scroll = """  void _onScroll() {
    if (_scrollController.hasClients && _scrollController.position.pixels <= _scrollController.position.minScrollExtent + 20) {
      if (_messageLimit < 500) { // arbitrary max
        setState(() {
          _messageLimit += 30;
        });
      }
    }
  }"""
new_scroll = """  void _onScroll() {
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
chat_screen = chat_screen.replace(old_scroll, new_scroll)

# Add _messagesStream to State
old_state_vars = """  final ScrollController _scrollController = ScrollController();
  MessageModel? _replyingTo;
  late String _chatId;
  bool _isFreelancer = false;
  
  bool _isTyping = false;
  int _messageLimit = 30;"""
new_state_vars = """  final ScrollController _scrollController = ScrollController();
  MessageModel? _replyingTo;
  late String _chatId;
  bool _isFreelancer = false;
  Stream<List<MessageModel>>? _messagesStream;
  
  bool _isTyping = false;
  int _messageLimit = 30;"""
chat_screen = chat_screen.replace(old_state_vars, new_state_vars)

# Initialize stream
old_init_chat = """        _chatId = '${myId}_${widget.targetUserId}';
      }
      
      if (mounted) setState(() {});
    }
  }"""
new_init_chat = """        _chatId = '${myId}_${widget.targetUserId}';
      }
      
      if (mounted) {
        setState(() {
          _messagesStream = context.read<ChatProvider>().getMessages(_chatId, limit: _messageLimit);
        });
      }
    }
  }"""
chat_screen = chat_screen.replace(old_init_chat, new_init_chat)

# Use _messagesStream instead of calling chatProvider.getMessages inline
old_inner_stream = """                      return StreamBuilder<List<MessageModel>>(
                        stream: chatProvider.getMessages(_chatId, limit: _messageLimit),
                        builder: (context, snapshot) {"""
new_inner_stream = """                      return StreamBuilder<List<MessageModel>>(
                        stream: _messagesStream,
                        builder: (context, snapshot) {"""
chat_screen = chat_screen.replace(old_inner_stream, new_inner_stream)

# Add reverse: true to ListView
old_listview = """                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount: messages.length,"""
new_listview = """                      return ListView.builder(
                        reverse: true,
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount: messages.length,"""
chat_screen = chat_screen.replace(old_listview, new_listview)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(chat_screen)

print("Fixed chat scrolling logic")
