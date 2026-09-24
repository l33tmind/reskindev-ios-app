import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    content = f.read()

# 1. Imports
if "import 'dart:async';" not in content:
    content = "import 'dart:async';\n" + content
if "import 'package:cloud_firestore/cloud_firestore.dart';" not in content:
    content = "import 'package:cloud_firestore/cloud_firestore.dart';\n" + content

# 2. _isTyping and _typingTimer
state_start = "class _ChatScreenState extends State<ChatScreen> {"
state_vars = """class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _chatId;
  bool _isFreelancer = false;
  
  bool _isTyping = false;
  Timer? _typingTimer;
"""
if state_start in content and "bool _isTyping" not in content:
    content = content.replace(
        """class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _chatId;
  bool _isFreelancer = false;""", state_vars)

# 3. initState
old_init = """  @override
  void initState() {
    super.initState();
    _chatId = widget.chatId;
    _initializeChat();
  }"""
new_init = """  @override
  void initState() {
    super.initState();
    _chatId = widget.chatId;
    _initializeChat();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_chatId.isEmpty || _chatId == 'new') return;
    final currentUserId = context.read<AuthProvider>().user?.uid;
    if (currentUserId == null) return;
    
    if (_controller.text.isNotEmpty) {
      if (!_isTyping) {
        _isTyping = true;
        context.read<ChatProvider>().setTyping(_chatId, currentUserId, true);
      }
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _isTyping = false;
        if (mounted) context.read<ChatProvider>().setTyping(_chatId, currentUserId, false);
      });
    } else {
      if (_isTyping) {
        _isTyping = false;
        _typingTimer?.cancel();
        context.read<ChatProvider>().setTyping(_chatId, currentUserId, false);
      }
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_isTyping && _chatId.isNotEmpty && _chatId != 'new') {
      final currentUserId = context.read<AuthProvider>().user?.uid;
      if (currentUserId != null) {
        context.read<ChatProvider>().setTyping(_chatId, currentUserId, false);
      }
    }
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }"""
if old_init in content:
    content = content.replace(old_init, new_init)

# 4. AppBar layout
old_appbar_title = """            Expanded(
              child: Text(
                widget.targetUserName,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: context.themeTextDark),
                overflow: TextOverflow.ellipsis,
              ),
            ),"""
new_appbar_title = """            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.targetUserName,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: context.themeTextDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_chatId.isNotEmpty && _chatId != 'new')
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('conversations').doc(_chatId).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
                        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                        final typingMap = data['typing'] as Map<String, dynamic>? ?? {};
                        final isTargetTyping = typingMap[widget.targetUserId] == true;
                        
                        if (isTargetTyping) {
                          return Text(
                            'Typing...',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                          );
                        }
                        // We will add online/last seen here later
                        return const SizedBox.shrink();
                      },
                    ),
                ],
              ),
            ),"""
if old_appbar_title in content:
    content = content.replace(old_appbar_title, new_appbar_title)

# 5. Date Headers and DateChip
old_list = """                          return ChatBubble(
                            message: msg, 
                            isMe: isMe,
                            isFirstInGroup: isFirst,
                            isLastInGroup: isLast,
                            isRead: isRead,
                          );"""

new_list = """                          Widget bubble = ChatBubble(
                            message: msg, 
                            isMe: isMe,
                            isFirstInGroup: isFirst,
                            isLastInGroup: isLast,
                            isRead: isRead,
                          );
                          
                          bool showDate = false;
                          if (index == 0) {
                            showDate = true;
                          } else {
                            final prevMsg = messages[index - 1];
                            if (msg.createdAt != null && prevMsg.createdAt != null) {
                              if (msg.createdAt!.day != prevMsg.createdAt!.day ||
                                  msg.createdAt!.month != prevMsg.createdAt!.month ||
                                  msg.createdAt!.year != prevMsg.createdAt!.year) {
                                showDate = true;
                              }
                            }
                          }
                          
                          if (showDate && msg.createdAt != null) {
                            return Column(
                              children: [
                                _buildDateChip(msg.createdAt!),
                                bubble,
                              ],
                            );
                          }
                          
                          return bubble;"""

if old_list in content:
    content = content.replace(old_list, new_list)

date_chip = """  Widget _buildMessageInput() {"""
new_date_chip = """  Widget _buildDateChip(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday = date.year == now.year && date.month == now.month && date.day == now.day - 1;
    
    String dateStr;
    if (isToday) dateStr = 'Today';
    else if (isYesterday) dateStr = 'Yesterday';
    else dateStr = '${date.day}/${date.month}/${date.year}';
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: context.themeBorder.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        dateStr,
        style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildMessageInput() {"""

if date_chip in content:
    content = content.replace(date_chip, new_date_chip)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(content)

print("Updated chat_screen.dart")
