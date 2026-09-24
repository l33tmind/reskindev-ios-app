import 'dart:io';

void main() {
  final file = File('lib/screens/profile_screen.dart');
  var content = file.readAsStringSync();
  
  final earningsMenu = '''
              const _MenuDivider(),
              _MenuTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Earnings',
                subtitle: 'Manage your income & withdrawals',
                onTap: () => context.push('/earnings'),
              ),
''';

  if (content.contains(earningsMenu)) {
    content = content.replaceFirst(earningsMenu, '');
    file.writeAsStringSync(content);
    print('Removed Earnings from Profile');
  } else {
    print('Could not find Earnings menu');
  }
}
