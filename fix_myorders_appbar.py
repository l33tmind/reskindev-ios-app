import re

with open('lib/screens/my_orders_screen.dart', 'r') as f:
    content = f.read()

old_appbar = """          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: context.themeSurface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 1,
            title: Text('My Orders', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: context.themeTextDark)),
          ),"""

new_appbar = """          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: context.themeSurface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 1,
            title: Text('My Orders', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: context.themeTextDark)),
            actions: [
              if (auth.isFreelancer)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextButton.icon(
                    onPressed: () => context.push('/seller'),
                    icon: Icon(Icons.dashboard_rounded, size: 16, color: AppTheme.primary),
                    label: Text('Seller Dashboard', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    style: TextButton.styleFrom(
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
            ],
          ),"""
content = content.replace(old_appbar, new_appbar)

with open('lib/screens/my_orders_screen.dart', 'w') as f:
    f.write(content)

print("Added Seller Dashboard button to MyOrdersScreen Mobile Appbar")
