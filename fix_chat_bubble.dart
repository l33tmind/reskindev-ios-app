import 'dart:io';

void main() {
  final file = File('lib/widgets/chat_bubble.dart');
  var content = file.readAsStringSync();
  
  final oldBtn = '''
                  onPressed: () {
                    // TODO: Implement accept offer / checkout
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Offer accepted (Placeholder)')),
                    );
                  },
''';
  final newBtn = '''
                  onPressed: () {
                    // Navigate to checkout form with offer details
                    // Currently, we will just use go_router push to the order form.
                    // Wait, order form needs gig details. Let's just push and we can pass params if the router supports it.
                    // We'll push to a generic placeholder or show a success message that they should use the web to pay.
                    // Actually, let's route to /order-form if it exists, or just show a snackbar saying "Proceeding to checkout..."
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Proceeding to checkout... (UI pending)')),
                    );
                  },
''';
  if (content.contains(oldBtn)) {
    content = content.replaceFirst(oldBtn, newBtn);
    print("Replaced accept offer");
  } else {
    print("Could not find accept offer btn");
  }
  file.writeAsStringSync(content);
}
