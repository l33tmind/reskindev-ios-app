import 'dart:io';

void main() {
  final file = File('lib/screens/my_orders_screen.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceFirst('class RatingDialog', '}\n\nclass RatingDialog');
  content = content.replaceFirst('}\n}', '}'); // Clean up the double brace at the end
  
  file.writeAsStringSync(content);
}
