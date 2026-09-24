import re

with open('lib/screens/profile_screen.dart', 'r') as f:
    c = f.read()

# Add quick replies under seller dashboard
old_menu = """                onTap: () => context.push('/seller'),
              ),
            ],
            const _MenuDivider(),
            _MenuTile(
              icon: Icons.logout_rounded,"""

new_menu = """                onTap: () => context.push('/seller'),
              ),
              const _MenuDivider(),
              _MenuTile(
                icon: Icons.bolt_rounded,
                iconColor: Colors.amber,
                title: 'Quick Replies',
                subtitle: 'Manage saved messages for chat',
                onTap: () => context.push('/quick-replies'),
              ),
            ],
            const _MenuDivider(),
            _MenuTile(
              icon: Icons.logout_rounded,"""

c = c.replace(old_menu, new_menu)

with open('lib/screens/profile_screen.dart', 'w') as f:
    f.write(c)

