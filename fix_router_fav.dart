import 'dart:io';

void main() {
  final file = File('lib/router.dart');
  var content = file.readAsStringSync();
  
  if (!content.contains('favorites_screen.dart')) {
    content = content.replaceFirst(
      "import 'screens/profile_screen.dart';",
      "import 'screens/profile_screen.dart';\nimport 'screens/favorites_screen.dart';"
    );
    
    final newRoute = '''
      GoRoute(
        path: 'favorites',
        builder: (context, state) => const FavoritesScreen(),
      ),
''';
    content = content.replaceFirst(
      "path: 'profile',",
      newRoute + "\n      path: 'profile',"
    );
  }

  file.writeAsStringSync(content);
  print('Added Favorites to router.dart');
}
