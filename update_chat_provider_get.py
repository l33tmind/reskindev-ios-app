with open('lib/providers/chat_provider.dart', 'r') as f:
    content = f.read()

method_to_add = """  // Get a single conversation
  Future<ConversationModel?> getConversation(String chatId) async {
    final doc = await _db.collection('conversations').doc(chatId).get();
    if (doc.exists && doc.data() != null) {
      return ConversationModel.fromMap(doc.id, doc.data()!);
    }
    return null;
  }

  // Send a text message"""

content = content.replace("  // Send a text message", method_to_add)

with open('lib/providers/chat_provider.dart', 'w') as f:
    f.write(content)
print("Updated chat_provider.dart")
