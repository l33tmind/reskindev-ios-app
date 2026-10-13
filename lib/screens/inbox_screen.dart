import '../services/invoice_number.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_models.dart';

import '../theme.dart';
import '../widgets/user_avatar.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({Key? key}) : super(key: key);

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return DateFormat('h:mm a').format(t);
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEE').format(t);
    return DateFormat('d MMM').format(t);
  }

  String _searchQuery = "";
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.user?.uid;

    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: context.themeBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Please log in to view messages.', style: GoogleFonts.inter(color: context.themeTextDark)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Login'),
              )
            ],
          ),
        ),
      );
    }

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        title: Text('Inbox', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
        backgroundColor: context.themeSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: context.themeTextDark),
      ),
      body: Column(
        children: [
          Container(
            color: context.themeSurface,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showArchived = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: !_showArchived ? AppTheme.primary : Colors.transparent, width: 2)),
                      ),
                      child: Center(child: Text('Active', style: GoogleFonts.inter(fontWeight: !_showArchived ? FontWeight.bold : FontWeight.normal, color: !_showArchived ? AppTheme.primary : context.themeTextLight))),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showArchived = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: _showArchived ? AppTheme.primary : Colors.transparent, width: 2)),
                      ),
                      child: Center(child: Text('Archived', style: GoogleFonts.inter(fontWeight: _showArchived ? FontWeight.bold : FontWeight.normal, color: _showArchived ? AppTheme.primary : context.themeTextLight))),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: context.themeSurface,
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                hintStyle: GoogleFonts.inter(color: context.themeTextLight),
                prefixIcon: Icon(Icons.search, color: context.themeTextLight),
                filled: true,
                fillColor: context.themeBackground,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ConversationModel>>(
              stream: chatProvider.getInbox(currentUserId, showArchived: _showArchived),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }

                var conversations = snapshot.data ?? [];
                
                // Filter by search query
                if (_searchQuery.isNotEmpty) {
                  conversations = conversations.where((chat) {
                    final otherUserId = chat.participants.firstWhere((id) => id != currentUserId, orElse: () => '');
                    final otherUser = chat.participantDetails[otherUserId] ?? {'name': 'Unknown'};
                    final name = otherUser['name'].toString().toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();
                }

                if (conversations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: context.themeBorder),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty ? 'No matches found.' : 'No messages yet.',
                          style: GoogleFonts.inter(color: context.themeTextLight, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: conversations.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: context.themeBorder.withOpacity(0.5), indent: 76),
                  itemBuilder: (context, index) {
                    final chat = conversations[index];
                    final otherUserId = chat.participants.firstWhere((id) => id != currentUserId, orElse: () => '');
                    final otherUser = chat.participantDetails[otherUserId] ?? {'name': 'Unknown', 'avatar': ''};
                    final unread = (chat.unreadCount[currentUserId] ?? 0);
                    final String avatarUrl = otherUser['avatar']?.toString() ?? '';
                    final String otherName = otherUser['name']?.toString() ?? 'Unknown';
                    final String name = otherName;

                    return Dismissible(
                      key: Key(chat.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: _showArchived ? Colors.blue : Colors.orange,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: Icon(_showArchived ? Icons.unarchive : Icons.archive, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        chatProvider.toggleArchive(chat.id, currentUserId, !_showArchived);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_showArchived ? 'Chat Unarchived' : 'Chat Archived')));
                      },
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onTap: () {
                        context.push('/chat/${chat.id}', extra: {
                          'targetUserName': name,
                          'targetUserId': otherUserId,
                          'targetUserAvatar': avatarUrl,
                        });
                      },
                      title: Row(
                        children: [
                          Expanded(
                            child: LiveUserName(
                              uid: otherUserId,
                              fallback: name,
                              style: GoogleFonts.outfit(fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w500, fontSize: 16, color: context.themeTextDark),
                            ),
                          ),
                        ],
                      ),
                      // Live profile photo (or colored initials), with a green dot when they're online
                      leading: UserAvatar(
                        uid: otherUserId,
                        name: name,
                        photoUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
                        radius: 26,
                        showOnline: true,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (chat.orderId != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.work_outline, size: 12, color: AppTheme.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'ORDER ${orderNumber(chat.orderId)}',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              chat.lastMessage.isEmpty ? 'Say hi!' : chat.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                                color: unread > 0 ? context.themeTextDark : context.themeTextLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (chat.updatedAt != null)
                            Text(
                              _formatTime(chat.updatedAt!),
                              style: GoogleFonts.inter(
                                fontSize: 12, 
                                fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                                color: unread > 0 ? AppTheme.primary : context.themeTextLight
                              ),
                            ),
                          const SizedBox(height: 6),
                          if (unread > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                              ),
                              child: Text(
                                unread.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            )
                          else 
                            const SizedBox(height: 20), // Placeholder to maintain alignment
                        ],
                      ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
