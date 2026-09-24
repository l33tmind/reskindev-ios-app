import 'dart:io';

void main() {
  final file = File('lib/screens/admin_dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceAll(
    ".where('status', isEqualTo: 'pending')",
    ".where(Filter.or(Filter('status', isEqualTo: 'pending_payment'), Filter('status', isEqualTo: 'pending')))"
  );
  
  file.writeAsStringSync(content);
}
