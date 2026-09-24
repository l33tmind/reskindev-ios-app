import re

with open('lib/router.dart', 'r') as f:
    c = f.read()

# Add import
if "import 'screens/quick_replies_screen.dart';" not in c:
    c = c.replace("import 'screens/profile_screen.dart';", "import 'screens/profile_screen.dart';\nimport 'screens/quick_replies_screen.dart';")

# Add route
old_route = """    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/seller',
      builder: (_, __) => const SellerDashboardScreen(),"""

new_route = """    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/quick-replies',
      builder: (_, __) => const QuickRepliesScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/seller',
      builder: (_, __) => const SellerDashboardScreen(),"""

c = c.replace(old_route, new_route)

with open('lib/router.dart', 'w') as f:
    f.write(c)

