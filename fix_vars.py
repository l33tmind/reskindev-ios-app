import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    content = f.read()

old_vars = """  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  MessageModel? _replyingTo;
  late String _chatId;
  bool _isFreelancer = false;
  
  bool _isTyping = false;
  Timer? _typingTimer;
  int _messageLimit = 30;"""

new_vars = """  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  MessageModel? _replyingTo;
  late String _chatId;
  bool _isFreelancer = false;
  Stream<List<MessageModel>>? _messagesStream;
  
  bool _isTyping = false;
  Timer? _typingTimer;
  int _messageLimit = 30;"""

content = content.replace(old_vars, new_vars)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(content)

print("Added _messagesStream")
