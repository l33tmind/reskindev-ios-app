import 'dart:io';

void main() {
  final file = File('lib/screens/chat_screen.dart');
  var content = file.readAsStringSync();

  // Fix 1: The 'Price ($)' -> 'Price (USD)'
  content = content.replaceAll("labelText: 'Price (\$)'", "labelText: 'Price (USD)'");

  // Fix 2: The sendMessage call
  final oldSend = '''
              final msg = MessageModel(
                id: '',
                text: 'Sent a custom offer',
                senderId: currentUser.uid,
                senderName: auth.displayName,
                type: 'offer',
                offerPrice: num.tryParse(priceCtrl.text) ?? 0,
                offerDays: int.tryParse(daysCtrl.text) ?? 0,
                offerDescription: descCtrl.text,
              );
              
              await context.read<ChatProvider>().sendMessage(_chatId, msg);
''';
  final newSend = '''
              await context.read<ChatProvider>().sendMessage(
                chatId: _chatId,
                currentUserId: currentUser.uid,
                currentUserName: auth.displayName ?? '',
                text: 'Sent a custom offer',
                type: 'offer',
                offerPrice: num.tryParse(priceCtrl.text) ?? 0,
                offerDays: int.tryParse(daysCtrl.text) ?? 0,
                offerDescription: descCtrl.text,
              );
''';
  if (content.contains(oldSend)) {
    content = content.replaceFirst(oldSend, newSend);
  } else {
    print("Could not find oldSend!");
  }

  file.writeAsStringSync(content);
  print('Fixed chat_screen.dart errors');
}
