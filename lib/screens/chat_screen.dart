import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_models.dart';
import '../models/order_model.dart';

import '../theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/order_chat_cards.dart';
import '../widgets/workspace_details_sheet.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String targetUserId;
  final String targetUserName;
  final String targetUserAvatar;
  final String? orderId;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.targetUserId,
    required this.targetUserName,
    required this.targetUserAvatar,
    this.orderId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  MessageModel? _replyingTo;
  late String _chatId;
  bool _isFreelancer = false;
  Stream<List<MessageModel>>? _messagesStream;
  String? _currentOrderId;

  bool _isTyping = false;
  Timer? _typingTimer;
  int _messageLimit = 20;
  List<String> _chatSuggestions = [];

  @override
  void initState() {
    super.initState();
    _chatId = widget.chatId;
    _initializeChat();
    _fetchChatSuggestions();
    _controller.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
  }

  Future<void> _fetchChatSuggestions() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('global')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('chatSuggestions')) {
          setState(() {
            _chatSuggestions = List<String>.from(data['chatSuggestions'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching chat suggestions: $e');
    }
  }

  void _onScroll() {
    // Auto pagination removed as per user request for "Show More" button.
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
        if (mounted)
          context.read<ChatProvider>().setTyping(_chatId, currentUserId, false);
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
  }

  Future<void> _initializeChat() async {
    final auth = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final currentUser = auth.user;

    if (currentUser == null) return;

    if (_chatId.isEmpty || _chatId == 'new') {
      if (widget.orderId != null && widget.orderId!.isNotEmpty) {
        _chatId = await chatProvider.getOrCreateOrderConversation(
          currentUserId: currentUser.uid,
          currentUserName: auth.displayName,
          currentUserAvatar: auth.photoUrl,
          targetUserId: widget.targetUserId,
          targetUserName: widget.targetUserName,
          targetUserAvatar: widget.targetUserAvatar,
          orderId: widget.orderId!,
        );
      } else {
        _chatId = await chatProvider.getOrCreateConversation(
          currentUserId: currentUser.uid,
          currentUserName: auth.displayName,
          currentUserAvatar: auth.photoUrl,
          targetUserId: widget.targetUserId,
          targetUserName: widget.targetUserName,
          targetUserAvatar: widget.targetUserAvatar,
        );
      }
    }

    if (mounted) {
      setState(() {
        _messagesStream = context.read<ChatProvider>().getMessages(
          _chatId,
          limit: _messageLimit,
        );
      });
    }

    // Mark as read when entering
    await chatProvider.markAsRead(_chatId, currentUser.uid);
  }

  Future<void> _showReportDialog() async {
    String selectedReason = 'Spam';
    final reasons = [
      'Spam',
      'Inappropriate Behavior',
      'Scam/Fraud',
      'Harassment',
      'Other',
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Why are you reporting this user?'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedReason,
                items: reasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => selectedReason = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                final currentUserId = context.read<AuthProvider>().user?.uid;
                if (currentUserId == null) return;

                await FirebaseFirestore.instance.collection('reports').add({
                  'reportedBy': currentUserId,
                  'reportedUser': widget.targetUserId,
                  'reason': selectedReason,
                  'createdAt': FieldValue.serverTimestamp(),
                  'status': 'pending',
                });

                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Report submitted successfully.'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBlockDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block User'),
        content: const Text(
          'Are you sure you want to block this user? You will not be able to send or receive messages from them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final currentUserId = context.read<AuthProvider>().user?.uid;
              if (currentUserId == null) return;

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUserId)
                  .update({
                    'blockedUsers': FieldValue.arrayUnion([
                      widget.targetUserId,
                    ]),
                  });

              if (mounted) {
                // User is blocked in DB.
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('User blocked.')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    final auth = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final currentUser = auth.user;

    if (currentUser == null) return;

    chatProvider.sendMessage(
      chatId: _chatId,
      currentUserId: currentUser.uid,
      currentUserName: auth.displayName,
      text: _controller.text.trim(),
      replyToId: _replyingTo?.id,
      replyToText: _replyingTo?.text,
      replyToSender: _replyingTo?.senderName,
    );

    setState(() {
      _replyingTo = null;
    });

    _controller.clear();

    // With reverse: true, we can optionally scroll to 0.0 (bottom)
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.user?.uid;

    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        backgroundColor: context.themeSurface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: context.themeTextDark),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              backgroundImage: widget.targetUserAvatar.isNotEmpty
                  ? NetworkImage(widget.targetUserAvatar)
                  : null,
              child: widget.targetUserAvatar.isEmpty
                  ? Text(
                      widget.targetUserName.isNotEmpty
                          ? widget.targetUserName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.targetUserName,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: context.themeTextDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_chatId.isNotEmpty && _chatId != 'new')
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('conversations')
                          .doc(_chatId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        bool isTargetTyping = false;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>? ??
                              {};
                          final typingMap =
                              data['typing'] as Map<String, dynamic>? ?? {};
                          isTargetTyping =
                              typingMap[widget.targetUserId] == true;
                        }

                        if (isTargetTyping) {
                          return Text(
                            'Typing...',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }

                        // If not typing, show Online status
                        if (widget.targetUserId.isEmpty) return const SizedBox.shrink();
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.targetUserId)
                              .snapshots(),
                          builder: (ctx, userSnapshot) {
                            if (!userSnapshot.hasData ||
                                !userSnapshot.data!.exists)
                              return const SizedBox.shrink();

                            final userData =
                                userSnapshot.data!.data()
                                    as Map<String, dynamic>? ??
                                {};
                            final isOnline = userData['isOnline'] == true;

                            if (isOnline) {
                              return Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Online',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                            }

                            final lastSeenRaw = userData['lastSeen'];
                            DateTime? lastSeen;
                            if (lastSeenRaw is Timestamp) {
                              lastSeen = lastSeenRaw.toDate();
                            } else if (lastSeenRaw is int) {
                              lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenRaw);
                            }
                            
                            if (lastSeen != null) {
                              final now = DateTime.now();
                              String timeStr;
                              if (now.difference(lastSeen).inDays > 1) {
                                timeStr = '${lastSeen.day}/${lastSeen.month}';
                              } else if (now.difference(lastSeen).inDays == 1) {
                                timeStr = 'Yesterday';
                              } else {
                                final hour = lastSeen.hour > 12
                                    ? lastSeen.hour - 12
                                    : (lastSeen.hour == 0 ? 12 : lastSeen.hour);
                                final ampm = lastSeen.hour >= 12 ? 'PM' : 'AM';
                                final min = lastSeen.minute.toString().padLeft(
                                  2,
                                  '0',
                                );
                                timeStr = '$hour:$min $ampm';
                              }
                              return Text(
                                'Last seen $timeStr',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: context.themeTextLight,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'profile') {
                context.push('/seller-profile/${widget.targetUserId}');
              } else if (value == 'report') {
                _showReportDialog();
              } else if (value == 'block') {
                _showBlockDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Text('View Profile'),
              ),
              const PopupMenuItem(value: 'report', child: Text('Report User')),
              const PopupMenuItem(value: 'block', child: Text('Block User')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_chatId.isNotEmpty && _chatId != 'new')
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('conversations').doc(_chatId).snapshots(),
              builder: (context, snapshot) {
                final chatData = snapshot.data?.data() as Map<String, dynamic>?;
                final orderId = chatData?['orderId'] as String?;
                if (orderId == null || orderId.isEmpty) return const SizedBox.shrink();
                
                return GestureDetector(
                  onTap: () {
                    _currentOrderId = orderId;
                    _showWorkspaceDetails();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      border: Border(bottom: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3))),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.workspace_premium_rounded, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Active Order Workspace',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
                          child: Text('View', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          Expanded(
            child: (_chatId.isEmpty || _chatId == 'new')
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('conversations')
                        .doc(_chatId)
                        .snapshots(),
                    builder: (context, chatSnap) {
                      int targetUnreadCount = 0;
                      if (chatSnap.hasData && chatSnap.data!.exists) {
                        final chatData =
                            chatSnap.data!.data() as Map<String, dynamic>? ??
                            {};
                        _currentOrderId = chatData['orderId'] as String?;
                        final unreadMap =
                            chatData['unreadCount'] as Map<String, dynamic>? ??
                            {};
                        targetUnreadCount =
                            (unreadMap[widget.targetUserId] as num?)?.toInt() ??
                            0;
                      }

                      return StreamBuilder<List<MessageModel>>(
                        stream: _messagesStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primary,
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text('Error loading messages: ${snapshot.error}', style: TextStyle(color: Colors.red)));
                          }

                          final messages = snapshot.data ?? [];

                          // Auto mark as read if new messages arrive
                          if (messages.isNotEmpty && currentUserId != null) {
                            chatProvider.markAsRead(_chatId, currentUserId);
                          }

                          return Align(
                            alignment: Alignment.topCenter,
                            child: ListView.builder(
                              reverse: true,
                              shrinkWrap: true,
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              itemCount:
                                  messages.length +
                                  (messages.length >= _messageLimit ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == messages.length) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _messageLimit += 20;
                                            _messagesStream = context
                                                .read<ChatProvider>()
                                                .getMessages(
                                                  _chatId,
                                                  limit: _messageLimit,
                                                );
                                          });
                                        },
                                        style: TextButton.styleFrom(
                                          backgroundColor: AppTheme.primary
                                              .withValues(alpha: 0.1),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Load More Messages',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                final msg = messages[index];
                                final isMe = msg.senderId == currentUserId;

                                bool isFirst = true;
                                bool isLast = true;

                                if (index < messages.length - 1) {
                                  final olderMsg = messages[index + 1];
                                  if (olderMsg.senderId == msg.senderId) {
                                    if (msg.createdAt != null &&
                                        olderMsg.createdAt != null) {
                                      if (msg.createdAt!
                                              .difference(olderMsg.createdAt!)
                                              .inMinutes
                                              .abs() <
                                          2) {
                                        isFirst = false;
                                      }
                                    } else {
                                      isFirst = false;
                                    }
                                  }
                                }

                                if (index > 0) {
                                  final newerMsg = messages[index - 1];
                                  if (newerMsg.senderId == msg.senderId) {
                                    if (msg.createdAt != null &&
                                        newerMsg.createdAt != null) {
                                      if (msg.createdAt!
                                              .difference(newerMsg.createdAt!)
                                              .inMinutes
                                              .abs() <
                                          2) {
                                        isLast = false;
                                      }
                                    } else {
                                      isLast = false;
                                    }
                                  }
                                }

                                // If target user's unread count is 0, they have read all messages
                                final isRead = targetUnreadCount == 0;

                                Widget bubble = Dismissible(
                                  key: Key(
                                    msg.id.isNotEmpty
                                        ? msg.id
                                        : UniqueKey().toString(),
                                  ),
                                  direction: DismissDirection.startToEnd,
                                  confirmDismiss: (direction) async {
                                    setState(() => _replyingTo = msg);
                                    return false; // Don't actually dismiss
                                  },
                                  background: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 20),
                                    color: Colors.transparent,
                                    child: const Icon(
                                      Icons.reply,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  child:
                                      (msg.isSystem ||
                                          (msg.type != 'text' &&
                                              msg.type != 'image'))
                                      ? OrderChatCardBuilder(
                                          message: msg,
                                          isCurrentUser: isMe,
                                          isFreelancer: _isFreelancer,
                                        )
                                      : ChatBubble(
                                          isFreelancer: _isFreelancer,
                                          message: msg,
                                          isMe: isMe,
                                          isFirstInGroup: isFirst,
                                          isLastInGroup: isLast,
                                          isRead: isRead,
                                        ),
                                );

                                bool showDate = false;
                                if (index == messages.length - 1) {
                                  showDate = true;
                                } else {
                                  final olderMsg = messages[index + 1];
                                  if (msg.createdAt != null &&
                                      olderMsg.createdAt != null) {
                                    if (msg.createdAt!.day !=
                                            olderMsg.createdAt!.day ||
                                        msg.createdAt!.month !=
                                            olderMsg.createdAt!.month ||
                                        msg.createdAt!.year !=
                                            olderMsg.createdAt!.year) {
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

                                return bubble;
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          if (widget.targetUserId.isEmpty) 
            const SizedBox.shrink()
          else
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.targetUserId)
                  .snapshots(),
            builder: (context, snapshot) {
              final auth = context.watch<AuthProvider>();
              final iBlockedThem = auth.blockedUsers.contains(
                widget.targetUserId,
              );

              bool theyBlockedMe = false;
              if (snapshot.hasData && snapshot.data!.exists) {
                final targetData =
                    snapshot.data!.data() as Map<String, dynamic>? ?? {};
                final targetBlocked = List<String>.from(
                  targetData['blockedUsers'] ?? [],
                );
                theyBlockedMe = targetBlocked.contains(auth.user?.uid);
              }

              if (iBlockedThem) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  color: context.themeSurface,
                  alignment: Alignment.center,
                  child: Text(
                    'You blocked this user. Unblock to send messages.',
                    style: GoogleFonts.inter(color: Colors.red),
                  ),
                );
              }
              if (theyBlockedMe) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  color: context.themeSurface,
                  alignment: Alignment.center,
                  child: Text(
                    'You cannot reply to this conversation.',
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildQuickReplies(auth),
                  if (_replyingTo != null) _buildReplyPreview(),
                  _buildMessageInput(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showCustomOfferModal() {
    final priceCtrl = TextEditingController();
    final daysCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: context.themeCard,
        title: Text(
          'Send Custom Offer',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: context.themeTextDark,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: context.themeTextDark),
                decoration: const InputDecoration(labelText: 'Price (USD)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: daysCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: context.themeTextDark),
                decoration: const InputDecoration(
                  labelText: 'Delivery Time (Days)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                style: TextStyle(color: context.themeTextDark),
                decoration: const InputDecoration(
                  labelText: 'Offer Description',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (priceCtrl.text.isEmpty ||
                  daysCtrl.text.isEmpty ||
                  descCtrl.text.isEmpty)
                return;

              final auth = context.read<AuthProvider>();
              final currentUser = auth.user;
              if (currentUser == null) return;

              Navigator.pop(c);

              await context.read<ChatProvider>().sendMessage(
                chatId: _chatId,
                currentUserId: currentUser.uid,
                currentUserName: auth.displayName,
                text: 'Sent a custom offer',
                type: 'offer',
                offerPrice: num.tryParse(priceCtrl.text) ?? 0,
                offerDays: int.tryParse(daysCtrl.text) ?? 0,
                offerDescription: descCtrl.text,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Offer'),
          ),
        ],
      ),
    );
  }

  void _showWorkspaceDetails() {
    if (_currentOrderId == null || _currentOrderId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This chat is not connected to a specific order.')),
        );
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: WorkspaceDetailsSheet(
                orderId: _currentOrderId!,
                isSeller: context.read<AuthProvider>().isFreelancer,
                chatId: _chatId,
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildDateChip(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday =
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1;

    String dateStr;
    if (isToday)
      dateStr = 'Today';
    else if (isYesterday)
      dateStr = 'Yesterday';
    else
      dateStr = '${date.day}/${date.month}/${date.year}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: context.themeBorder.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        dateStr,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: context.themeTextLight,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildQuickReplies(AuthProvider auth) {
    if (!auth.isFreelancer) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(auth.user?.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final savedReplies = List<String>.from(data?['quickReplies'] ?? []);
        
        final templates = savedReplies.isNotEmpty ? savedReplies : [
          "Let's start a Google Meet call for better communication",
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
                label: Text(
                  templates[index],
                  style: TextStyle(
                    fontSize: 13,
                    color: context.themeTextDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
      },
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
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppTheme.primary,
                  ),
                ),
                Text(
                  _replyingTo!.text,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.themeTextDark,
                  ),
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

  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: context.themeSurface,
        border: Border(top: BorderSide(color: context.themeBorder)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Quick Reply Chips ──────────────────────────────────
            if (_chatSuggestions.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _chatSuggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _chatSuggestions[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          _controller.text = suggestion;
                          _controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: suggestion.length),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            suggestion,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (_chatSuggestions.isNotEmpty) const SizedBox(height: 8),
            // ── Input Row ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  if (_isFreelancer) ...[
                    IconButton(
                      icon: const Icon(
                        Icons.local_offer_outlined,
                        color: AppTheme.primary,
                      ),
                      onPressed: _showCustomOfferModal,
                      tooltip: 'Send Custom Offer',
                    ),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    icon: Icon(Icons.info_outline_rounded, color: context.themeTextLight),
                    onPressed: _showWorkspaceDetails,
                    tooltip: 'Work Details',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.themeBackground, // Using theme background which is greyish/softer
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.newline,
                        minLines: 1,
                        maxLines: 5,
                        style: GoogleFonts.inter(color: context.themeTextDark),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: GoogleFonts.inter(
                            color: context.themeTextLight,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
