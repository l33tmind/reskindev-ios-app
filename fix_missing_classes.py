import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

# Make sure we add the closing brace for _HomeScreenState
# We will append the missing classes after it.

missing_classes = """
  // Ensure the state class is closed properly
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE APP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _MobileAppBar extends StatelessWidget {
  final ap.AuthProvider auth;
  final SettingsProvider settings;

  const _MobileAppBar({required this.auth, required this.settings});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      backgroundColor: context.themeBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/logo.png', height: 28, errorBuilder: (_,__,___) => const SizedBox.shrink()),
          const SizedBox(width: 8),
          Text(
            'Reskindev',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: context.themeTextDark,
            ),
          ),
        ],
      ),
      leading: IconButton(
        icon: Icon(Icons.menu, color: context.themeTextDark),
        onPressed: () {
          Scaffold.of(context).openDrawer();
        },
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: GestureDetector(
            onTap: () {
              if (auth.user != null) {
                context.go('/profile');
              } else {
                context.push('/login');
              }
            },
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: Icon(Icons.person, size: 18, color: AppTheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final SettingsProvider settings;
  final ap.AuthProvider auth;
  final VoidCallback onExploreTap;

  const _HeroBanner({
    required this.settings,
    required this.auth,
    required this.onExploreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium App\nDevelopment',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Hire expert developers to bring your ideas to life.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onExploreTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(
              'Explore Services',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH BAR DELEGATE
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final List<GigModel> gigs;
  final bool isLoading;

  _SearchBarDelegate({required this.gigs, required this.isLoading});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: context.themeBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => SearchBottomSheet(gigs: gigs),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: context.themeSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.themeBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: context.themeTextLight, size: 20),
              const SizedBox(width: 12),
              Text(
                'Search services...',
                style: GoogleFonts.inter(color: context.themeTextLight, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 64.0;

  @override
  double get minExtent => 64.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// GIG GRID SLIVER
// ─────────────────────────────────────────────────────────────────────────────
class _GigGridSliver extends StatelessWidget {
  final List<GigModel> gigs;
  const _GigGridSliver({required this.gigs});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final gig = gigs[i];
            final slug = gig.title
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                .replaceAll(RegExp(r'^-+|-+$'), '');
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 400 + (i * 100).clamp(0, 500)),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutQuart,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: GigCard(
                gig: gig,
                onTap: () {
                  if (kIsWeb) {
                    context.go('/gig/${gig.id}/$slug');
                  } else {
                    context.push('/gig/${gig.id}/$slug');
                  }
                },
              ),
            );
          },
          childCount: gigs.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 220,
        ),
      ),
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.themeCard,
      highlightColor: context.themeSurface,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
          mainAxisExtent: 220,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _EmptyGigs extends StatelessWidget {
  const _EmptyGigs();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: context.themeTextLight),
            const SizedBox(height: 16),
            Text('No gigs found', style: GoogleFonts.outfit(fontSize: 20, color: context.themeTextDark)),
          ],
        ),
      ),
    );
  }
}

"""

# We need to append this after _buildMobileLayout
# Currently the file ends at the end of _buildMobileLayout and there are other classes appended (the new sections).
# Wait, my previous script appended _VisualCategoriesList and others to the VERY end of the file.
# The missing classes should be injected before _VisualCategoriesList!
# Also, I need to make sure I add `}` to close `_HomeScreenState`.

if "class _MobileAppBar" not in content:
    # Find the end of _buildMobileLayout
    build_mobile_idx = content.find("  Widget _buildMobileLayout(")
    
    # We will just append all the missing classes to the end of the file, it doesn't matter as long as the state class is closed properly.
    # Currently the file DOES NOT have `}` to close _HomeScreenState.
    # Let's see where the state class actually is.
    # We can just append `}\n` right after the `_buildMobileLayout` method ends.
    # But wait, how do I know where `_buildMobileLayout` ends?
    # I can just search for the start of `class _VisualCategoriesList` and insert `}` before it.
    
    insert_idx = content.find("class _VisualCategoriesList")
    if insert_idx != -1:
        new_content = content[:insert_idx] + missing_classes + content[insert_idx:]
        with open('lib/screens/home_screen.dart', 'w') as f:
            f.write(new_content)
        print("Restored missing classes successfully")
    else:
        print("Could not find _VisualCategoriesList")
else:
    print("Classes already exist")
