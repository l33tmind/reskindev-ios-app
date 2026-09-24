import re

with open('lib/providers/chat_provider.dart', 'r') as f:
    content = f.read()

if "Future<void> setTyping" not in content:
    typing_func = """
  // Set typing status
  Future<void> setTyping(String chatId, String userId, bool isTyping) async {
    final chatRef = _db.collection('conversations').doc(chatId);
    await chatRef.update({
      'typing.$userId': isTyping,
    });
  }
}
"""
    content = content.replace('\n}', typing_func)
    with open('lib/providers/chat_provider.dart', 'w') as f:
        f.write(content)
    print("Added setTyping")
else:
    print("setTyping already exists")
