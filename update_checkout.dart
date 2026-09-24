import 'dart:io';

void main() {
  final file = File('lib/screens/order_form_screen.dart');
  var content = file.readAsStringSync();
  
  // Update status from 'requirements' to 'pending_payment'
  content = content.replaceAll(
    "status: 'requirements', // Web schema: starts as 'requirements'",
    "status: 'pending_payment',"
  );
  
  file.writeAsStringSync(content);
  print('Updated order_form_screen.dart');
}
