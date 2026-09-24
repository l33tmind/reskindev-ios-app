import 'dart:io';

void main() {
  final file = File('lib/router.dart');
  var content = file.readAsStringSync();
  
  if (!content.contains('seller_profile_screen.dart')) {
    content = content.replaceFirst(
      "import 'screens/favorites_screen.dart';",
      "import 'screens/favorites_screen.dart';\nimport 'screens/seller_profile_screen.dart';"
    );
    
    final newRoute = '''
      GoRoute(
        path: 'seller-profile/:id',
        builder: (context, state) => SellerProfileScreen(sellerId: state.pathParameters['id']!),
      ),
''';
    content = content.replaceFirst(
      "path: 'profile',",
      newRoute + "\n      path: 'profile',"
    );
  }

  file.writeAsStringSync(content);
  print('Added SellerProfile to router.dart');
}
