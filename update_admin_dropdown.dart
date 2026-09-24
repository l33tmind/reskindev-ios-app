import 'dart:io';

void main() {
  final file = File('lib/screens/admin_dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  final oldList = '''
          items: [
            'pending',
            'in_progress',
            'completed',
            'cancelled',
          ].map((String value) {
''';

  final newList = '''
          items: [
            'pending_payment',
            'requirements',
            'in_progress',
            'delivered',
            'completed',
            'cancelled',
          ].map((String value) {
''';

  if (content.contains(oldList)) {
    content = content.replaceAll(oldList, newList);
    
    // Also we need to make sure _getStatusColor supports these
    // Wait, let's look at _getStatusColor
    
    file.writeAsStringSync(content);
    print('Updated dropdown options in admin dashboard');
  } else {
    print('Could not find old list');
  }
}
