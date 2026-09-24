import 'dart:io';

void main() {
  final file = File('lib/screens/seller_dashboard_screen.dart');
  var content = file.readAsStringSync();

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
      'class _SellerOrdersView', 
      supportModal + '\nclass _SellerOrdersView'
    );
  }

  // Find where to put the "Contact Support" button in the seller order card
  final oldAction = '''
                ],
              ),
            ),
            _buildSellerAction(context, order),
          ],
        ),
      ),
    );
  }
''';
  final newAction = '''
                ],
              ),
            ),
            _buildSellerAction(context, order),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => _showSupportModal(context, order, order.authorId),
                style: TextButton.styleFrom(foregroundColor: Colors.grey, padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                child: const Text('Report Issue', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
''';
  if (content.contains(oldAction)) {
    content = content.replaceFirst(oldAction, newAction);
    print("Added Support to seller dashboard");
  } else {
    print("Could not find oldAction");
  }

  file.writeAsStringSync(content);
}
