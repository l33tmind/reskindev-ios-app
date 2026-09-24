import re

with open('lib/router.dart', 'r') as f:
    content = f.read()

favorites_route = """
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/favorites',
      builder: (_, __) => const FavoritesScreen(),
    ),
"""

if "path: '/favorites'" not in content:
    # insert before '/appearance'
    old = """    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/appearance',"""
    content = content.replace(old, favorites_route + old)
    with open('lib/router.dart', 'w') as f:
        f.write(content)
    print("Added /favorites route")
else:
    print("Already has /favorites route")
