import 'dart:io';

void main() {
  final file = File('lib/screens/my_orders_screen.dart');
  var content = file.readAsStringSync();
  
  // Let's add a global _showSupportModal function at the top or inside
  final supportModal = '''
void _showSupportModal(BuildContext context, OrderModel order, String reportedBy) {
  final subjCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: context.themeCard,
      title: Text('Contact Support', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Describe the issue you are facing with this order.', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
            const SizedBox(height: 16),
            TextField(
              controller: subjCtrl,
              style: TextStyle(color: context.themeTextDark),
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 4,
              style: TextStyle(color: context.themeTextDark),
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (subjCtrl.text.isEmpty || descCtrl.text.isEmpty) return;
            Navigator.pop(c);
            await FirebaseFirestore.instance.collection('support_tickets').add({
              'orderId': order.id,
              'gigTitle': order.gigTitle,
              'reportedByUid': reportedBy,
              'subject': subjCtrl.text,
              'description': descCtrl.text,
              'status': 'open',
              'createdAt': FieldValue.serverTimestamp(),
            });
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support ticket created. We will contact you soon.')));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          child: const Text('Submit Ticket'),
        ),
      ],
    ),
  );
}
''';

  if (!content.contains('_showSupportModal')) {
    content = content.replaceFirst(
      'class _OrderDetailsSheet', 
      supportModal + '\nclass _OrderDetailsSheet'
    );
  }

  final oldCloseBtn = '''
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),
''';
  final newCloseBtn = '''
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showSupportModal(context, order, order.clientUid);
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                      child: const Text('Report Issue / Contact Support'),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),
''';
  if (content.contains(oldCloseBtn)) {
    content = content.replaceFirst(oldCloseBtn, newCloseBtn);
    print("Added Support to my_orders");
  } else {
    print("Could not find close button in my_orders");
  }

  file.writeAsStringSync(content);
}
