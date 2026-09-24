import 'dart:io';

void main() {
  final file = File('lib/providers/chat_provider.dart');
  var content = file.readAsStringSync();

  final oldFn = '''
  Future<void> sendMessage({
    required String chatId,
    required String currentUserId,
    required String currentUserName,
    required String text,
  }) async {
    final batch = _db.batch();

    final chatRef = _db.collection('conversations').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

    final msg = MessageModel(
      id: msgRef.id,
      text: text,
      senderId: currentUserId,
      senderName: currentUserName,
      createdAt: DateTime.now(),
    );
''';
  
  final newFn = '''
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

    final msg = MessageModel(
      id: msgRef.id,
      text: text,
      senderId: currentUserId,
      senderName: currentUserName,
      createdAt: DateTime.now(),
      type: type,
      offerPrice: offerPrice,
      offerDays: offerDays,
      offerDescription: offerDescription,
    );
''';

  if (content.contains(oldFn)) {
    content = content.replaceFirst(oldFn, newFn);
  } else {
    print("Could not find oldFn");
  }

  file.writeAsStringSync(content);
  print('Updated chat_provider.dart');
}
