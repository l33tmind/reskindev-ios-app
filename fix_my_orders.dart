import 'dart:io';

void main() {
  final file = File('lib/screens/my_orders_screen.dart');
  var content = file.readAsStringSync();
  
  final oldButtons = '''
                      ElevatedButton(
                        onPressed: () {
                          // Show the Rating and Review Dialog!
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (c) => RatingDialog(order: order),
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1BCA75), foregroundColor: Colors.white),
                        child: const Text('Approve & Accept Delivery'),
                      ),
                    ),
                  ],
''';

  final newButtons = '''
                      ElevatedButton(
                        onPressed: () {
                          // Show the Rating and Review Dialog!
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (c) => RatingDialog(order: order),
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1BCA75), foregroundColor: Colors.white),
                        child: const Text('Approve & Accept Delivery'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _showRevisionModal(context, order),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                        child: const Text('Request Revision'),
                      ),
                    ),
                  ],
''';
  
  if (content.contains(oldButtons)) {
    content = content.replaceFirst(oldButtons, newButtons);
  } else {
    print("Could not find Approve buttons");
  }

  // Also add _showRevisionModal function to _OrderDetailsSheet or globally.
  // Wait, _OrderDetailsSheet is probably a StatelessWidget or Stateful. Let's see what class it is in.
  // Let's insert the function before the class closes.
  
  final revisionModalFn = '''
  void _showRevisionModal(BuildContext context, OrderModel order) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: context.themeCard,
        title: Text('Request Revision', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What needs to be changed?', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 4,
              style: TextStyle(color: context.themeTextDark),
              decoration: const InputDecoration(hintText: 'Please describe the revisions needed...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (noteCtrl.text.trim().isEmpty) return;
              Navigator.pop(c);
              await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                'status': 'revision',
                'revisionNote': noteCtrl.text.trim(),
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revision Requested!')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }
''';

  content = content.replaceFirst('class _OrderDetailsSheet extends StatelessWidget {', revisionModalFn + '\nclass _OrderDetailsSheet extends StatelessWidget {');

  file.writeAsStringSync(content);
  print('Added Request Revision button');
}
