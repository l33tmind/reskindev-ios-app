import 'dart:io';

void main() {
  final file = File('lib/screens/my_orders_screen.dart');
  var content = file.readAsStringSync();
  
  final oldTimeline = '''
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),
''';

  final newTimeline = '''
                  if (order.status == 'delivered') ...[
                    const Divider(height: 32),
                    _buildDetailRow(context, 'Delivery Note', order.deliveryNote.isEmpty ? 'No note provided' : order.deliveryNote),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                            'status': 'completed',
                            'completedAt': FieldValue.serverTimestamp(),
                          });
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1BCA75), foregroundColor: Colors.white),
                        child: const Text('Approve & Accept Delivery'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),
''';

  if (content.contains(oldTimeline)) {
    content = content.replaceAll(oldTimeline, newTimeline);
    file.writeAsStringSync(content);
    print('Updated buyer actions');
  } else {
    print('Could not find old timeline in my_orders_screen');
  }
}
