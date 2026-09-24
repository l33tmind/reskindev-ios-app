import re

with open('lib/router.dart', 'r') as f:
    c = f.read()

old_route = """    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/seller',
      builder: (_, __) => const SellerDashboardScreen(),
      routes: ["""

new_route = """    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/seller',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context,
        state: state,
        child: const SellerDashboardScreen(),
      ),
      routes: ["""

c = c.replace(old_route, new_route)

with open('lib/router.dart', 'w') as f:
    f.write(c)
