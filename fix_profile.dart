import 'dart:io';

void main() {
  final file = File('lib/screens/profile_screen.dart');
  var content = file.readAsStringSync();
  
  final oldMenu = '''
                onTap: () => context.push('/seller'),
              ),
            ],
            const _MenuDivider(),
''';

  final newMenu = '''
                onTap: () => context.push('/seller'),
              ),
              const _MenuDivider(),
              _MenuTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Earnings',
                subtitle: 'Manage your income & withdrawals',
                onTap: () => context.push('/earnings'),
              ),
            ],
            const _MenuDivider(),
''';

  if (content.contains(oldMenu)) {
    content = content.replaceFirst(oldMenu, newMenu);
    file.writeAsStringSync(content);
    print('Updated profile menu');
  } else {
    print('Could not find seller menu item');
  }
}
