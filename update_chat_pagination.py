import re

with open('lib/providers/chat_provider.dart', 'r') as f:
    content = f.read()

old_getmsg = """  // Stream of messages for a specific conversation
  Stream<List<MessageModel>> getMessages(String chatId) {
    return _db
        .collection('conversations')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
            .toList());
  }"""

new_getmsg = """  // Stream of messages for a specific conversation
  Stream<List<MessageModel>> getMessages(String chatId, {int limit = 30}) {
    return _db
        .collection('conversations')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limitToLast(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
            .toList());
  }"""

if old_getmsg in content:
    content = content.replace(old_getmsg, new_getmsg)
    with open('lib/providers/chat_provider.dart', 'w') as f:
        f.write(content)
    print("Added limit parameter to getMessages")
else:
    print("Could not find getMessages block")
