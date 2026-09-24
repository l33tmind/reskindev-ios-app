import 'dart:io';

void main() {
  final file = File('lib/screens/profile_screen.dart');
  var content = file.readAsStringSync();
  
  final oldTiles = '''
            _MenuTile(
              icon: Icons.receipt_long_outlined,
              title: 'My Orders',
              subtitle: 'View your order history',
              onTap: () => context.push('/my-orders'),
            ),
''';
  final newTiles = '''
            _MenuTile(
              icon: Icons.receipt_long_outlined,
              title: 'My Orders',
              subtitle: 'View your order history',
              onTap: () => context.push('/my-orders'),
            ),
            const _MenuDivider(),
            _MenuTile(
              icon: Icons.favorite_border_rounded,
              title: 'Wishlist',
              subtitle: 'Your saved services',
              onTap: () => context.push('/favorites'),
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
