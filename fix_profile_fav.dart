import 'dart:io';

void main() {
  final file = File('lib/screens/profile_screen.dart');
  var content = file.readAsStringSync();
  
  final oldTiles = '''
                      _MenuTile(
                        icon: Icons.history_rounded,
                        title: 'Order History',
                        onTap: () => context.go('/orders'),
                      ),
''';
  final newTiles = '''
                      _MenuTile(
                        icon: Icons.favorite_border_rounded,
                        title: 'Wishlist',
                        onTap: () => context.go('/favorites'),
                      ),
                      _MenuTile(
                        icon: Icons.history_rounded,
                        title: 'Order History',
                        onTap: () => context.go('/orders'),
                      ),
''';
  if (content.contains(oldTiles)) {
    content = content.replaceFirst(oldTiles, newTiles);
    print("Added Favorites to Profile");
  } else {
    print("Could not find oldTiles");
  }

  file.writeAsStringSync(content);
}
