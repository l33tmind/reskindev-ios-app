import 'dart:io';

void main() {
  final file = File('lib/providers/chat_provider.dart');
  var content = file.readAsStringSync();
  
  final oldFn = '''
  // Send a text message
  Future<void> sendMessage({
    required String chatId,
    required String currentUserId,
    required String currentUserName,
    required String text,
  }) async {
    final batch = _db.batch();

    final chatRef = _db.collection('conversations').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

    // Create the message
    final msgData = {
      'text': text,
      'senderId': currentUserId,
      'senderName': currentUserName,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'text',
    };
    batch.set(msgRef, msgData);
''';
  final newFn = '''
  // Send a text message
  Future<void> sendMessage({
    required String chatId,
    required String currentUserId,
    required String currentUserName,
    required String text,
    String type = 'text',
    num? offerPrice,
    int? offerDays,
    String? offerDescription,
  }) async {
    final batch = _db.batch();

    final chatRef = _db.collection('conversations').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

    // Create the message
    final msgData = {
      'text': text,
      'senderId': currentUserId,
      'senderName': currentUserName,
      'createdAt': FieldValue.serverTimestamp(),
      'type': type,
      if (offerPrice != null) 'offerPrice': offerPrice,
      if (offerDays != null) 'offerDays': offerDays,
      if (offerDescription != null) 'offerDescription': offerDescription,
    };
    batch.set(msgRef, msgData);
''';
  if (content.contains(oldFn)) {
    content = content.replaceFirst(oldFn, newFn);
  } else {
    print("Not found!");
  }
  file.writeAsStringSync(content);
}
