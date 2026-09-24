import re

with open('lib/providers/chat_provider.dart', 'r') as f:
    content = f.read()

helper = """
  Future<void> sendSystemMessage({
    required String buyerId,
    required String buyerName,
    required String sellerId,
    required String sellerName,
    required String orderId,
    required String gigTitle,
    required String actionType,
    required String text,
  }) async {
    try {
      // 1. Check if a conversation already exists between buyer and seller
      final QuerySnapshot chatQuery = await _db
          .collection('conversations')
          .where('participants', arrayContains: buyerId)
          .get();
          
      String? existingChatId;
      for (var doc in chatQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        List<dynamic> participants = data['participants'] ?? [];
        if (participants.contains(sellerId)) {
          existingChatId = doc.id;
          break;
        }
      }
      
      // 2. Create chat if it doesn't exist
      if (existingChatId == null) {
        DocumentReference newChat = await _db.collection('conversations').add({
          'participants': [buyerId, sellerId],
          'participantDetails': {
            buyerId: {'name': buyerName},
            sellerId: {'name': sellerName},
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': text,
        });
        existingChatId = newChat.id;
      } else {
        // Update last message
        await _db.collection('conversations').doc(existingChatId).update({
          'lastMessage': text,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // 3. Insert the system message
      await _db
          .collection('conversations')
          .doc(existingChatId)
          .collection('messages')
          .add({
        'type': 'system_notification',
        'actionType': actionType,
        'text': text,
        'orderId': orderId,
        'gigTitle': gigTitle,
        'senderId': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Failed to send system message: $e");
    }
  }
"""

if "sendSystemMessage" not in content:
    # insert before the last closing brace
    content = content.rstrip()
    if content.endswith('}'):
        content = content[:-1] + helper + "\n}\n"
    with open('lib/providers/chat_provider.dart', 'w') as f:
        f.write(content)
    print("Added sendSystemMessage to ChatProvider")
else:
    print("Already exists")
