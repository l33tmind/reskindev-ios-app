import 'dart:io';

void main() {
  final file = File('lib/screens/my_orders_screen.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceFirst('class _StatCard', '}\n\nclass _StatCard');
  
  file.writeAsStringSync(content);
}
