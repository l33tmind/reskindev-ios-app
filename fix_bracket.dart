import 'dart:io';
void main() {
  final file = File('lib/screens/gig_editor_screen.dart');
  final lines = file.readAsLinesSync();
  lines.removeRange(92, 95);
  file.writeAsStringSync(lines.join('\n'));
}
