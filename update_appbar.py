import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    content = f.read()

old_appbar = """                  if (_chatId.isNotEmpty && _chatId != 'new')
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
                    ),"""

new_appbar = """                  if (_chatId.isNotEmpty && _chatId != 'new')
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('conversations').doc(_chatId).snapshots(),
                      builder: (context, snapshot) {
                        bool isTargetTyping = false;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                          final typingMap = data['typing'] as Map<String, dynamic>? ?? {};
                          isTargetTyping = typingMap[widget.targetUserId] == true;
                        }
                        
                        if (isTargetTyping) {
                          return Text(
                            'Typing...',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                          );
                        }
                        
                        // If not typing, show Online status
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).snapshots(),
                          builder: (ctx, userSnapshot) {
                            if (!userSnapshot.hasData || !userSnapshot.data!.exists) return const SizedBox.shrink();
                            
                            final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                            final isOnline = userData['isOnline'] == true;
                            
                            if (isOnline) {
                              return Row(
                                children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('Online', style: GoogleFonts.inter(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500)),
                                ],
                              );
                            }
                            
                            final lastSeenTs = userData['lastSeen'] as Timestamp?;
                            if (lastSeenTs != null) {
                              final lastSeen = lastSeenTs.toDate();
                              final now = DateTime.now();
                              String timeStr;
                              if (now.difference(lastSeen).inDays > 1) {
                                timeStr = '${lastSeen.day}/${lastSeen.month}';
                              } else if (now.difference(lastSeen).inDays == 1) {
                                timeStr = 'Yesterday';
                              } else {
                                final hour = lastSeen.hour > 12 ? lastSeen.hour - 12 : (lastSeen.hour == 0 ? 12 : lastSeen.hour);
                                final ampm = lastSeen.hour >= 12 ? 'PM' : 'AM';
                                final min = lastSeen.minute.toString().padLeft(2, '0');
                                timeStr = '$hour:$min $ampm';
                              }
                              return Text('Last seen $timeStr', style: GoogleFonts.inter(fontSize: 11, color: context.themeTextLight));
                            }
                            return const SizedBox.shrink();
                          },
                        );
                      },
                    ),"""

if old_appbar in content:
    content = content.replace(old_appbar, new_appbar)
    with open('lib/screens/chat_screen.dart', 'w') as f:
        f.write(content)
    print("Updated AppBar for presence")
else:
    print("Could not find AppBar block")
