import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    content = f.read()

# Add _messageLimit and scroll listener
state_start = """  bool _isTyping = false;
  Timer? _typingTimer;"""

state_vars = """  bool _isTyping = false;
  Timer? _typingTimer;
  int _messageLimit = 30;"""

if state_start in content:
    content = content.replace(state_start, state_vars)

old_init = """  @override
  void initState() {
    super.initState();
    _chatId = widget.chatId;
    _initializeChat();
    _controller.addListener(_onTextChanged);
  }"""

new_init = """  @override
  void initState() {
    super.initState();
    _chatId = widget.chatId;
    _initializeChat();
    _controller.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients && _scrollController.position.pixels <= _scrollController.position.minScrollExtent + 20) {
      if (_messageLimit < 500) { // arbitrary max
        setState(() {
          _messageLimit += 30;
        });
      }
    }
  }"""

if old_init in content:
    content = content.replace(old_init, new_init)

old_stream = """stream: chatProvider.getMessages(_chatId),"""
new_stream = """stream: chatProvider.getMessages(_chatId, limit: _messageLimit),"""

if old_stream in content:
    content = content.replace(old_stream, new_stream)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(content)

print("Added pagination")
