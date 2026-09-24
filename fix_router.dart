import 'dart:io';

void main() {
  final file = File('lib/router.dart');
  var content = file.readAsStringSync();
  
  if (!content.contains('import \'screens/earnings_screen.dart\';')) {
    content = content.replaceFirst('import \'screens/inbox_screen.dart\';', 'import \'screens/inbox_screen.dart\';\nimport \'screens/earnings_screen.dart\';');
  }

  if (!content.contains('GoRoute(path: \'/earnings\'')) {
    final newRoute = '''
      GoRoute(path: '/my-orders', builder: (context, state) => const MyOrdersScreen()),
      GoRoute(path: '/earnings', builder: (context, state) => const EarningsScreen()),
''';
    content = content.replaceFirst('GoRoute(path: \'/my-orders\', builder: (context, state) => const MyOrdersScreen()),', newRoute);
    file.writeAsStringSync(content);
    print('Updated router');
  } else {
    print('Router already updated');
  }
}
