import 'dart:io';

void main() {
  final file = File('lib/screens/inbox_screen.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceAll(
    '  const InboxScreen({Key? key}) : super(key: key);\n\n  @override\n  @override',
    '  @override'
  );
  
  file.writeAsStringSync(content);
}
