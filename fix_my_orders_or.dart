import 'dart:io';

void main() {
  final file = File('lib/screens/my_orders_screen.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceFirst(
    ".where('userId', isEqualTo: auth.user!.uid)",
    ".where(Filter.or(Filter('userId', isEqualTo: auth.user!.uid), Filter('clientUid', isEqualTo: auth.user!.uid)))"
  );
  
  file.writeAsStringSync(content);
}
