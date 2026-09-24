import 'dart:io';

void main() {
  final file = File('lib/screens/inbox_screen.dart');
  var content = file.readAsStringSync();
  
  if (content.contains('class InboxScreen extends StatelessWidget {')) {
    content = content.replaceAll(
      'class InboxScreen extends StatelessWidget {',
      'class InboxScreen extends StatefulWidget {\n  const InboxScreen({Key? key}) : super(key: key);\n\n  @override\n  State<InboxScreen> createState() => _InboxScreenState();\n}\n\nclass _InboxScreenState extends State<InboxScreen> {'
    );
  }

  // Add search state
  if (!content.contains('String _searchQuery = "";')) {
    final stateStart = content.indexOf('class _InboxScreenState extends State<InboxScreen> {') + 'class _InboxScreenState extends State<InboxScreen> {'.length;
    content = content.substring(0, stateStart) + '\n  String _searchQuery = "";\n' + content.substring(stateStart);
  }

  // Replace build method signature if it was stateless
  content = content.replaceAll('Widget build(BuildContext context) {', '@override\n  Widget build(BuildContext context) {');

  // Find the AppBar
  final appBarOld = '''
      appBar: AppBar(
        title: Text('Inbox', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
        backgroundColor: context.themeSurface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: context.themeTextDark),
      ),
''';

  final appBarNew = '''
      appBar: AppBar(
        title: Text('Inbox', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
        backgroundColor: context.themeSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: context.themeTextDark),
      ),
''';

  content = content.replaceAll(appBarOld, appBarNew);

  // Modify the body to include a Search Bar and beautiful list
  final streamBuilderStart = content.indexOf('body: StreamBuilder<List<ConversationModel>>(');
  if (streamBuilderStart != -1) {
     final oldBodyText = content.substring(streamBuilderStart);
     // We will replace the entire body.
     // So let's truncate content and append the new body
     content = content.substring(0, streamBuilderStart);
     
     final newBody = '''body: Column(
        children: [
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
              stream: chatProvider.getInbox(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: \${snapshot.error}', style: const TextStyle(color: Colors.red)));
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
                    final String name = otherUser['name']?.toString() ?? 'Unknown';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      onTap: () {
                        context.push('/chat/\${chat.id}', extra: {
                          'targetUserName': name,
                          'targetUserId': otherUserId,
                          'targetUserAvatar': avatarUrl,
                        });
                      },
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppTheme.primary.withOpacity(0.1),
                            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl.isEmpty
                                ? Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?', style: GoogleFonts.outfit(color: AppTheme.primary, fontSize: 20, fontWeight: FontWeight.bold))
                                : null,
                          ),
                          // Online indicator mock (you can implement real status later)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(color: context.themeSurface, width: 2),
                              ),
                            ),
                          )
                        ],
                      ),
                      title: Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
                          color: context.themeTextDark,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          chat.lastMessage.isEmpty ? 'Say hi!' : chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                            color: unread > 0 ? context.themeTextDark : context.themeTextLight,
                          ),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (chat.updatedAt != null)
                            Text(
                              DateFormat('hh:mm a').format(chat.updatedAt!),
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
''';
     content = content + newBody;
  }
  
  file.writeAsStringSync(content);
}
