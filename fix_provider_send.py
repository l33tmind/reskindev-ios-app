import re

with open('lib/providers/chat_provider.dart', 'r') as f:
    content = f.read()

old_send = """  Future<void> sendMessage({
    required String chatId,
    required String currentUserId,
    required String currentUserName,
    required String targetUserId,
    required String text,
  }) async {"""

new_send = """  Future<void> sendMessage({
    required String chatId,
    required String currentUserId,
    required String currentUserName,
    required String targetUserId,
    required String text,
    String? replyToId,
    String? replyToText,
    String? replyToSender,
  }) async {"""

content = content.replace(old_send, new_send)

old_add = """      final msg = MessageModel(
        id: '',
        text: text,
        senderId: currentUserId,
        senderName: currentUserName,
      );"""

new_add = """      final msg = MessageModel(
        id: '',
        text: text,
        senderId: currentUserId,
        senderName: currentUserName,
        replyToId: replyToId,
        replyToText: replyToText,
        replyToSender: replyToSender,
      );"""

content = content.replace(old_add, new_add)

with open('lib/providers/chat_provider.dart', 'w') as f:
    f.write(content)
print("Updated sendMessage in provider")
