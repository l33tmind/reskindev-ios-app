import re

with open('lib/providers/chat_provider.dart', 'r') as f:
    c = f.read()

old_getInbox = """  Stream<List<ConversationModel>> getInbox(String currentUserId) {
    return _db
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ConversationModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }"""

new_getInbox = """  Stream<List<ConversationModel>> getInbox(String currentUserId, {bool showArchived = false}) {
    return _db
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) {
             final list = snapshot.docs.map((doc) => ConversationModel.fromMap(doc.id, doc.data())).toList();
             return list.where((chat) => showArchived ? chat.archivedBy.contains(currentUserId) : !chat.archivedBy.contains(currentUserId)).toList();
          }
        );
  }
  
  Future<void> toggleArchive(String chatId, String userId, bool archive) async {
    final ref = _db.collection('conversations').doc(chatId);
    if (archive) {
      await ref.update({'archivedBy': FieldValue.arrayUnion([userId])});
    } else {
      await ref.update({'archivedBy': FieldValue.arrayRemove([userId])});
    }
  }"""

c = c.replace(old_getInbox, new_getInbox)

# When a new message is sent, un-archive the chat for both users (or at least for the receiver)
# Actually, the simplest way is to clear `archivedBy` whenever a message is sent so it pops up for everyone.
old_sendMsg = "      'updatedAt': FieldValue.serverTimestamp(),\n    });"
new_sendMsg = "      'updatedAt': FieldValue.serverTimestamp(),\n      'archivedBy': [],\n    });"
c = c.replace(old_sendMsg, new_sendMsg)

with open('lib/providers/chat_provider.dart', 'w') as f:
    f.write(c)
