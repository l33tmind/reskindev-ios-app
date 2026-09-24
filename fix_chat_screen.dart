import 'dart:io';

void main() {
  final file = File('lib/screens/chat_screen.dart');
  var content = file.readAsStringSync();
  
  final oldInput = '''
        child: Row(
          children: [
            Expanded(
              child: Container(
''';
  final newInput = '''
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.local_offer_outlined, color: AppTheme.primary),
              onPressed: _showCustomOfferModal,
              tooltip: 'Send Custom Offer',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
''';
  if (content.contains(oldInput)) {
    content = content.replaceFirst(oldInput, newInput);
  } else {
    print("Could not find oldInput");
  }

  // Insert the _showCustomOfferModal method before the class closes
  final offerModal = '''
  void _showCustomOfferModal() {
    final priceCtrl = TextEditingController();
    final daysCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: context.themeCard,
        title: Text('Send Custom Offer', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: context.themeTextDark),
                decoration: const InputDecoration(labelText: 'Price (\$)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: daysCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: context.themeTextDark),
                decoration: const InputDecoration(labelText: 'Delivery Time (Days)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                style: TextStyle(color: context.themeTextDark),
                decoration: const InputDecoration(labelText: 'Offer Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (priceCtrl.text.isEmpty || daysCtrl.text.isEmpty || descCtrl.text.isEmpty) return;
              
              final auth = context.read<AuthProvider>();
              final currentUser = auth.user;
              if (currentUser == null) return;
              
              Navigator.pop(c);
              
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
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Send Offer'),
          ),
        ],
      ),
    );
  }
''';

  content = content.replaceFirst('  Widget _buildMessageInput() {', offerModal + '\n  Widget _buildMessageInput() {');

  file.writeAsStringSync(content);
  print('Added Custom Offer modal');
}
