import 'dart:io';

void main() {
  final file = File('lib/screens/admin_dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  final oldMethod = '''
  Color _getStatusColor(String status) {
    switch (status) {
      case 'in_progress': return const Color(0xFF3B82F6);
      case 'completed': return const Color(0xFF1BCA75);
      case 'cancelled': return const Color(0xFFEF4444);
      default: return const Color(0xFFF59E0B);
    }
  }
''';

  final newMethod = '''
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_payment': return const Color(0xFFEF4444); // Red
      case 'in_progress': return const Color(0xFF3B82F6); // Blue
      case 'delivered': return const Color(0xFF8B5CF6); // Purple
      case 'completed': return const Color(0xFF1BCA75); // Green
      case 'cancelled': return const Color(0xFFEF4444); // Red
      default: return const Color(0xFFF59E0B); // Amber
    }
  }
''';

  content = content.replaceAll(oldMethod, newMethod);
  file.writeAsStringSync(content);
}
