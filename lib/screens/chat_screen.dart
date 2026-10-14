
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io' show File;

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
import '../widgets/order_next_step_panel.dart';
import '../widgets/user_avatar.dart';
import '../widgets/pro_badge.dart';
import '../services/pro_service.dart' show isPro;
import '../widgets/custom_offer.dart';
import '../widgets/chat_media_preview.dart';
import 'quick_replies_screen.dart' show QuickReplyDefaults;
import '../services/notification_feed.dart';
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

  /// The chat on screen right now, or null
  static String? get openChatId => _ChatScreenState.openChatId;
  static set openChatId(String? id) => _ChatScreenState.openChatId = id;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  /// The chat on screen right now (null when none). Push notifications for it are not shown as a banner,
  /// because the person is already reading it.
  static String? openChatId;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  MessageModel? _replyingTo;
  late String _chatId;
  String? _lastReadMessageId;
  bool _isFreelancer = false;
  Stream<List<MessageModel>>? _messagesStream;
  String? _currentOrderId;
  ChatProvider? _chatProvider;
  late String _targetUserId;
  late String _targetUserName;
  late String _targetUserAvatar;

  bool _isTyping = false;
  Timer? _typingTimer;
  int _messageLimit = 20;
  List<String> _chatSuggestions = [];
  bool _uploadingMedia = false;
  /// Video upload progress 0..1 (null for photos / unknown)
  double? _uploadProgress;
  /// Status of the order linked to this chat (null when there is no order)
  String? _orderStatus;

  @override
  void initState() {
    super.initState();
    _chatId = widget.chatId;
    _targetUserId = widget.targetUserId;
    _targetUserName = widget.targetUserName;
    _targetUserAvatar = widget.targetUserAvatar;
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
    if (ChatScreen.openChatId == _chatId) ChatScreen.openChatId = null;
    _typingTimer?.cancel();
    if (_isTyping && _chatId.isNotEmpty && _chatId != 'new') {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        _chatProvider?.setTyping(_chatId, currentUserId, false);
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
    _chatProvider = chatProvider;
    // Opened from a push notification: the route carries only the chat id, and on a cold start the
    // auth state may not be restored yet, so wait for it before loading the chat.
    final currentUser = auth.user ??
        FirebaseAuth.instance.currentUser ??
        await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(seconds: 10), onTimeout: () => null);
    if (currentUser == null || !mounted) return;

    if (_chatId.isNotEmpty && _chatId != 'new' && _targetUserId.isEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('conversations')
            .doc(_chatId)
            .get();
        final data = doc.data();
        if (data != null) {
          final participants = List<String>.from(data['participants'] ?? []);
          final other = participants.firstWhere(
            (id) => id != currentUser.uid,
            orElse: () => '',
          );
          final details = (data['participantDetails'] as Map?)?[other] as Map?;
          if (mounted) {
            setState(() {
              _targetUserId = other;
              _targetUserName = (details?['name'] as String?) ?? _targetUserName;
              _targetUserAvatar = (details?['avatar'] as String?) ?? _targetUserAvatar;
              _currentOrderId = data['orderId'] as String?;
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading chat from notification: $e');
      }
    }
    if (!mounted) return;

    if (_chatId.isEmpty || _chatId == 'new') {
      if (widget.orderId != null && widget.orderId!.isNotEmpty) {
        _chatId = await chatProvider.getOrCreateOrderConversation(
          currentUserId: currentUser.uid,
          currentUserName: auth.displayName,
          currentUserAvatar: auth.photoUrl,
          targetUserId: _targetUserId,
          targetUserName: _targetUserName,
          targetUserAvatar: _targetUserAvatar,
          orderId: widget.orderId!,
        );
      } else {
        _chatId = await chatProvider.getOrCreateConversation(
          currentUserId: currentUser.uid,
          currentUserName: auth.displayName,
          currentUserAvatar: auth.photoUrl,
          targetUserId: _targetUserId,
          targetUserName: _targetUserName,
          targetUserAvatar: _targetUserAvatar,
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

    ChatScreen.openChatId = _chatId;
    _loadMyRole(currentUser.uid);

    // Mark as read when entering
    await chatProvider.markAsRead(_chatId, currentUser.uid);
    AppNotif.markChatRead(currentUser.uid, chatId: _chatId, orderId: widget.orderId ?? _currentOrderId);
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
                  'reportedUser': _targetUserId,
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
                      _targetUserId,
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

  /// The other person's profile picture beside their messages, shown on the last message of a group.
  /// Am I the seller in this chat? Order chat: the order's seller. Direct chat: the conversation's
  /// freelancerId (the person who was contacted about their gig). Not the account's role:
  /// every new account (guests too) gets role "freelancer", so that said nothing about this chat.
  Future<void> _loadMyRole(String myUid) async {
    try {
      final chat = (await FirebaseFirestore.instance.collection('conversations').doc(_chatId).get()).data();
      final orderId = (chat?['orderId'] ?? widget.orderId ?? '').toString();
      bool seller;
      if (orderId.isNotEmpty) {
        final order = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
        seller = (order.data()?['authorId'] ?? '') == myUid;
      } else {
        var sellerId = (chat?['freelancerId'] ?? '').toString();
        if (sellerId.isEmpty) {
          // No roles saved (older chat): whoever sent the first message is the buyer, the other one the seller.
          // Saved on the chat, so every app and the website agree from now on.
          final first = await FirebaseFirestore.instance
              .collection('conversations').doc(_chatId).collection('messages')
              .orderBy('createdAt').limit(1).get();
          final firstSender = first.docs.isEmpty ? '' : (first.docs.first.data()['senderId'] ?? '').toString();
          final participants = List<String>.from(chat?['participants'] ?? const []);
          if (firstSender.isNotEmpty && firstSender != 'system' && participants.length == 2 && participants.contains(firstSender)) {
            sellerId = participants.firstWhere((p) => p != firstSender);
            await FirebaseFirestore.instance.collection('conversations').doc(_chatId)
                .set({'freelancerId': sellerId, 'clientId': firstSender}, SetOptions(merge: true));
          }
        }
        seller = sellerId == myUid;
      }
      if (mounted && seller != _isFreelancer) setState(() => _isFreelancer = seller);
    } catch (_) {}
  }

  Widget _withAvatar({required MessageModel msg, required bool isMe, required bool isLast, required Widget bubble}) {
    if (isMe) return bubble;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          // Only next to the last bubble of a group, like iMessage/WhatsApp; live photo from their profile
          child: isLast
              ? Center(
                  child: UserAvatar(
                    uid: _targetUserId,
                    name: msg.senderName.isNotEmpty ? msg.senderName : _targetUserName,
                    radius: 16,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Expanded(child: bubble),
      ],
    );
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
        title: StreamBuilder<DocumentSnapshot>(
          stream: _targetUserId.isNotEmpty 
              ? FirebaseFirestore.instance.collection('users').doc(_targetUserId).snapshots() 
              : null,
          builder: (context, userSnapshot) {
            String displayAvatar = _targetUserAvatar;
            String displayName = _targetUserName;
            bool targetIsPro = false;
            bool targetVerified = false;
            
            if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
              final data = userSnapshot.data!.data() as Map<String, dynamic>?;
              targetIsPro = isPro(data);
              targetVerified = data?['verified'] == true;
              if (data != null) {
                displayAvatar = data['photoUrl'] ?? data['profilePicture'] ?? displayAvatar;
                final n = data['name'] ?? data['displayName'] ?? data['username'] ?? '';
                if (n.isNotEmpty) displayName = n;
              }
            }
            
            return Row(
              children: [
                // Tap the picture to see their profile
                GestureDetector(
                  onTap: _targetUserId.isEmpty ? null : () => context.push('/seller-profile/$_targetUserId'),
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Center(
                      child: UserAvatar(uid: _targetUserId, name: displayName, photoUrl: displayAvatar, radius: 19),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: context.themeTextDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (targetVerified) ...[
                            const SizedBox(width: 4),
                            const VerifiedTick(size: 15),
                          ],
                          if (targetIsPro) ...[
                            const SizedBox(width: 6),
                            const ProBadge(fontSize: 9),
                          ],
                        ],
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
                              typingMap[_targetUserId] == true;
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
                        if (_targetUserId.isEmpty) return const SizedBox.shrink();
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(_targetUserId)
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
        );
          }
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'details') {
                _showWorkspaceDetails();
              } else if (value == 'profile') {
                context.push('/seller-profile/${_targetUserId}');
              } else if (value == 'report') {
                _showReportDialog();
              } else if (value == 'block') {
                _showBlockDialog();
              }
            },
            itemBuilder: (context) => [
              if ((_currentOrderId ?? widget.orderId ?? '').isNotEmpty)
                const PopupMenuItem(value: 'details', child: Text('Order details')),
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
                
                // Fetch order to determine role
                if (_currentOrderId != orderId) {
                  _currentOrderId = orderId;
                  FirebaseFirestore.instance.collection('orders').doc(orderId).get().then((doc) {
                    if (doc.exists && mounted) {
                      final order = OrderModel.fromFirestore(doc);
                      setState(() {
                        _isFreelancer = FirebaseAuth.instance.currentUser?.uid == order.authorId;
                      });
                    }
                  });
                }
                
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
                  builder: (context, orderSnap) {
                    if (!orderSnap.hasData || !orderSnap.data!.exists) return const SizedBox.shrink();
                    final order = OrderModel.fromFirestore(orderSnap.data!);
                    _rememberOrderStatus(order.status);
                    
                    return OrderNextStepPanel(
                      order: order,
                      isSeller: FirebaseAuth.instance.currentUser?.uid == order.authorId,
                      chatId: _chatId,
                      onDetails: () {
                        _currentOrderId = orderId;
                        _showWorkspaceDetails();
                      },
                    );
                  }
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
                            (unreadMap[_targetUserId] as num?)?.toInt() ??
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

                          // Mark as read when a new message arrives (not on every rebuild:
                          // typing and online status redraw this often, and each call reads the chat)
                          if (messages.isNotEmpty && currentUserId != null && messages.first.id != _lastReadMessageId) {
                            _lastReadMessageId = messages.first.id;
                            chatProvider.markAsRead(_chatId, currentUserId);
                          }

                          // A new chat: say who it is and how to start, instead of an empty screen
                          if (messages.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    UserAvatar(uid: _targetUserId, name: _targetUserName, radius: 36),
                                    const SizedBox(height: 14),
                                    Text('Say hi to ${_targetUserName.split(' ').first} 👋',
                                      style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                                    const SizedBox(height: 6),
                                    Text(
                                      _isFreelancer
                                          ? 'Answer their questions here. When you agree on the work, send a custom offer with the 🏷 button.'
                                          : 'Ask about the service, the price or the delivery time. Tap ⚡ for ready-made questions.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(fontSize: 13.5, height: 1.45, color: context.themeTextLight),
                                    ),
                                  ],
                                ),
                              ),
                            );
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
                                          chatId: _chatId,
                                        )
                                      : _withAvatar(
                                          msg: msg,
                                          isMe: isMe,
                                          isLast: isLast,
                                          bubble: ChatBubble(
                                            isFreelancer: _isFreelancer,
                                            message: msg,
                                            isMe: isMe,
                                            isFirstInGroup: isFirst,
                                            isLastInGroup: isLast,
                                            isRead: isRead,
                                          ),
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
          if (_targetUserId.isEmpty) 
            const SizedBox.shrink()
          else
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(_targetUserId)
                  .snapshots(),
            builder: (context, snapshot) {
              final auth = context.watch<AuthProvider>();
              final iBlockedThem = auth.blockedUsers.contains(
                _targetUserId,
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
    final isOrderWorkspace = (_currentOrderId != null && _currentOrderId!.isNotEmpty) || (widget.orderId != null && widget.orderId!.isNotEmpty);
    if (isOrderWorkspace) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom offers can only be sent in direct buyer-seller chat, not inside an active order workstream.')),
      );
      return;
    }
    showCreateOfferSheet(context, chatId: _chatId);
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
      // The sheet sizes itself to its content (up to 85% of the screen) and scrolls inside
      builder: (context) => WorkspaceDetailsSheet(
        orderId: _currentOrderId!,
        chatId: _chatId,
      ),
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

  /// Seller can send a custom offer only before there is an order in this chat.
  bool get _canSendOffer =>
      _isFreelancer &&
      !((_currentOrderId != null && _currentOrderId!.isNotEmpty) ||
          (widget.orderId != null && widget.orderId!.isNotEmpty));

  /// Order statuses where the order is paid, so photos and videos can be shared in the chat.
  static const _paidOrderStatuses = {
    'requirements', 'processing', 'in_progress', 'revision', 'delivered', 'completed', 'disputed',
  };

  /// Photos and videos in an order chat whose order is paid (buyer and seller),
  /// or in any conversation (direct chats too) when I'm a Reskindev Pro member.
  bool get _canSendMedia =>
      ((_currentOrderId ?? widget.orderId ?? '').isNotEmpty &&
          _orderStatus != null &&
          _paidOrderStatuses.contains(_orderStatus)) ||
      (_chatId.isNotEmpty && _chatId != 'new' && Provider.of<AuthProvider>(context, listen: false).isPro);

  static const int _maxPhotoBytes = 5 * 1024 * 1024;
  static const int _maxVideoBytes = 100 * 1024 * 1024;

  /// Called from the order stream: remembers the order status so the "+" menu can show media options.
  void _rememberOrderStatus(String status) {
    if (_orderStatus == status) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _orderStatus != status) setState(() => _orderStatus = status);
    });
  }

  void _showMediaSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _attachTile(BuildContext ctx, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: context.themeTextDark)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12.5, color: context.themeTextLight)),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
    );
  }

  /// The "+" menu next to the message box: Photo / Video in a paid order chat (any chat for Pro), Create offer for the seller.
  void _showAttachMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.themeSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_canSendMedia) ...[
                _attachTile(ctx, Icons.photo_outlined, 'Photo', 'Up to 5 MB, from your library', _pickAndSendPhoto),
                _attachTile(ctx, Icons.videocam_outlined, 'Video', 'Up to 100 MB, from your library', _pickAndSendVideo),
              ],
              if (_canSendOffer)
                _attachTile(ctx, Icons.local_offer_outlined, 'Create offer', 'Send a custom offer to this buyer', _showCustomOfferModal),
            ],
          ),
        ),
      ),
    );
  }

  /// Picks a photo from the library, uploads it to Storage and sends it as an image message.
  Future<void> _pickAndSendPhoto() async {
    if (_uploadingMedia) return;
    final auth = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final currentUser = auth.user;
    if (currentUser == null) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;
      // Preview first; the size check (after image_picker compression) is shown there and disables Send
      final send = await showChatMediaPreview(
        context,
        file: picked,
        isVideo: false,
        maxBytes: _maxPhotoBytes,
        tooLargeMessage: 'Photos up to 5 MB',
      );
      if (!send || !mounted) return;
      if (await picked.length() > _maxPhotoBytes) {
        _showMediaSnack('Photos up to 5 MB');
        return;
      }
      setState(() {
        _uploadingMedia = true;
        _uploadProgress = null;
      });

      final bytes = await picked.readAsBytes();
      final ref = FirebaseStorage.instance
          .ref('chat_images/$_chatId/${DateTime.now().millisecondsSinceEpoch}_${currentUser.uid}.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();

      await chatProvider.sendMessage(
        chatId: _chatId,
        currentUserId: currentUser.uid,
        currentUserName: auth.displayName,
        text: '',
        type: 'image',
        imageUrl: url,
      );
      _scrollToNewest();
    } catch (e) {
      debugPrint('Chat photo upload failed: $e');
      _showMediaSnack('Could not send the photo. Please try again.');
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  /// Picks a video from the library, uploads it with progress and sends it as a video message.
  Future<void> _pickAndSendVideo() async {
    if (_uploadingMedia) return;
    final auth = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final currentUser = auth.user;
    if (currentUser == null) return;

    StreamSubscription<TaskSnapshot>? progressSub;
    try {
      final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      final send = await showChatMediaPreview(
        context,
        file: picked,
        isVideo: true,
        maxBytes: _maxVideoBytes,
        tooLargeMessage: 'Videos up to 100 MB, or share a Google Drive / WeTransfer link',
      );
      if (!send || !mounted) return;
      if (await picked.length() > _maxVideoBytes) {
        _showMediaSnack('Videos up to 100 MB, or share a Google Drive / WeTransfer link');
        return;
      }

      final name = (picked.name.isNotEmpty ? picked.name : picked.path).toLowerCase();
      final isMov = name.endsWith('.mov') || (picked.mimeType ?? '').contains('quicktime');
      final ext = isMov ? 'mov' : 'mp4';
      final contentType = isMov ? 'video/quicktime' : 'video/mp4';

      setState(() {
        _uploadingMedia = true;
        _uploadProgress = 0;
      });

      final ref = FirebaseStorage.instance
          .ref('chat_videos/$_chatId/${DateTime.now().millisecondsSinceEpoch}_${currentUser.uid}.$ext');
      // putFile streams from disk, so a big video is not loaded into memory
      final task = ref.putFile(File(picked.path), SettableMetadata(contentType: contentType));
      progressSub = task.snapshotEvents.listen((snap) {
        if (!mounted || snap.totalBytes <= 0) return;
        setState(() => _uploadProgress = snap.bytesTransferred / snap.totalBytes);
      });
      await task;
      final url = await ref.getDownloadURL();

      await chatProvider.sendMessage(
        chatId: _chatId,
        currentUserId: currentUser.uid,
        currentUserName: auth.displayName,
        text: '',
        type: 'video',
        videoUrl: url,
      );
      _scrollToNewest();
    } catch (e) {
      debugPrint('Chat video upload failed: $e');
      _showMediaSnack('Could not send the video. Please try again.');
    } finally {
      await progressSub?.cancel();
      if (mounted) {
        setState(() {
          _uploadingMedia = false;
          _uploadProgress = null;
        });
      }
    }
  }

  void _scrollToNewest() {
    if (mounted && _scrollController.hasClients) {
      _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  /// Quick replies for both sides: sellers and buyers each have their own list (editable in Profile → Quick Replies)
  bool _canUseQuickReplies(AuthProvider auth) => auth.user != null;

  /// Opens the saved quick replies. Tapping one puts it in the message box, so it can be edited before sending.
  Future<void> _showQuickReplies() async {
    final uid = context.read<AuthProvider>().user?.uid;
    List<String> saved = [];
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      saved = List<String>.from(doc.data()?[QuickReplyDefaults.field(seller: _isFreelancer)] ?? []);
    } catch (_) {}
    final templates = saved.isNotEmpty ? saved : QuickReplyDefaults.forRole(seller: _isFreelancer);
    if (!mounted) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.themeSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Quick replies',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/quick-replies', extra: _isFreelancer ? 'seller' : 'buyer');
                    },
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (final t in templates)
                    ListTile(
                      leading: const Icon(Icons.bolt_rounded, color: AppTheme.primary, size: 20),
                      title: Text(t, style: GoogleFonts.inter(fontSize: 14.5, color: context.themeTextDark)),
                      onTap: () => Navigator.pop(ctx, t),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _controller.text = picked;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: picked.length));
    setState(() {});
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
                  // "+" menu: Photo (buyer and seller) and Create offer (seller, before there is an order)
                  if (_uploadingMedia) ...[
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppTheme.primary,
                              value: _uploadProgress,
                            ),
                          ),
                          if (_uploadProgress != null)
                            Text(
                              '${(_uploadProgress! * 100).round()}%',
                              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.primary),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                  ] else if (_canSendMedia || _canSendOffer) ...[
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary),
                      onPressed: _showAttachMenu,
                      tooltip: _canSendMedia ? 'Photo or video' : 'Create offer',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (_canUseQuickReplies(context.watch<AuthProvider>())) ...[
                    IconButton(
                      icon: const Icon(Icons.bolt_rounded, color: AppTheme.primary),
                      onPressed: _showQuickReplies,
                      tooltip: 'Quick replies',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    const SizedBox(width: 8),
                  ],
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
