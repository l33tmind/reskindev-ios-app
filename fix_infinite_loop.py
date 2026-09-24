import re

with open('lib/providers/chat_provider.dart', 'r') as f:
    content = f.read()

old_mark = """    if (unreadCount[currentUserId] != null && unreadCount[currentUserId]! > 0) {
      unreadCount[currentUserId] = 0;
      await chatRef.update({
        'unreadCount': unreadCount,
        'lastReadTime.$currentUserId': FieldValue.serverTimestamp(),
      });
    } else {
      // Just update lastReadTime anyway
      await chatRef.update({
        'lastReadTime.$currentUserId': FieldValue.serverTimestamp(),
      });
    }"""

new_mark = """    if (unreadCount[currentUserId] != null && unreadCount[currentUserId]! > 0) {
      unreadCount[currentUserId] = 0;
      await chatRef.update({
        'unreadCount': unreadCount,
        'lastReadTime.$currentUserId': FieldValue.serverTimestamp(),
      });
    }"""

content = content.replace(old_mark, new_mark)

with open('lib/providers/chat_provider.dart', 'w') as f:
    f.write(content)

print("Fixed infinite loop in chat_provider")
