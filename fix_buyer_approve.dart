import 'dart:io';

void main() {
  final file = File('lib/screens/my_orders_screen.dart');
  var content = file.readAsStringSync();
  
  final oldAction = '''
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
''';

  final newAction = '''
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx); // close details modal
                          showDialog(
                            context: context, // use main context
                            barrierDismissible: false,
                            builder: (c) => RatingDialog(order: order),
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1BCA75), foregroundColor: Colors.white),
                        child: const Text('Approve & Accept Delivery'),
                      ),
''';

  if (content.contains(oldAction)) {
    content = content.replaceFirst(oldAction, newAction);
    file.writeAsStringSync(content);
    print('Updated approve action');
  } else {
    print('Could not find old approve action');
  }
}
