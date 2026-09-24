import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    content = f.read()

# Replace the body to wrap with conversation stream
old_body = """      body: Column(
        children: [
          Expanded(
            child: (_chatId.isEmpty || _chatId == 'new')
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : StreamBuilder<List<MessageModel>>(
                    stream: chatProvider.getMessages(_chatId, limit: _messageLimit),
                    builder: (context, snapshot) {"""

new_body = """      body: Column(
        children: [
          Expanded(
            child: (_chatId.isEmpty || _chatId == 'new')
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('conversations').doc(_chatId).snapshots(),
                    builder: (context, chatSnap) {
                      int targetUnreadCount = 0;
                      if (chatSnap.hasData && chatSnap.data!.exists) {
                        final chatData = chatSnap.data!.data() as Map<String, dynamic>? ?? {};
                        final unreadMap = chatData['unreadCount'] as Map<String, dynamic>? ?? {};
                        targetUnreadCount = (unreadMap[widget.targetUserId] as num?)?.toInt() ?? 0;
                      }
                      
                      return StreamBuilder<List<MessageModel>>(
                        stream: chatProvider.getMessages(_chatId, limit: _messageLimit),
                        builder: (context, snapshot) {"""

if old_body in content:
    content = content.replace(old_body, new_body)

# Replace the isRead mock
old_isRead = """                          // Mocking isRead for now since we don't have conversation stream here.
                          // It will just show double blue tick for all sent messages.
                          final isRead = true; """

new_isRead = """                          // If target user's unread count is 0, they have read all messages
                          final isRead = targetUnreadCount == 0;"""

if old_isRead in content:
    content = content.replace(old_isRead, new_isRead)

# We added a StreamBuilder, so we need to close it.
old_close = """                        },
                      );
                    },
                  ),
          ),"""

new_close = """                        },
                      );
                    },
                  );
                },
              ),
          ),"""

if old_close in content:
    content = content.replace(old_close, new_close)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(content)
print("Updated Read Receipts in Flutter")
