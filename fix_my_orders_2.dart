import 'dart:io';

void main() {
  final file = File('lib/screens/my_orders_screen.dart');
  var content = file.readAsStringSync();

  final oldBtn = '''
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
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
''';

  final newBtn = '''
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
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showRevisionModal(context, order);
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                        child: const Text('Request Revision'),
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
''';
  if (content.contains(oldBtn)) {
    content = content.replaceFirst(oldBtn, newBtn);
  } else {
    print("Not found!");
  }

  file.writeAsStringSync(content);
  print('Added Request Revision button!');
}
