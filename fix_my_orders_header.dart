import 'dart:io';

void main() {
  final file = File('lib/screens/my_orders_screen.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceFirst('const _OrderDetailsSheet({required this.order});', 'const _OrderDetailsSheet({super.key, required this.order});');
  
  file.writeAsStringSync(content);
}
