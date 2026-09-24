import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

# 1. New classes to append to the file
new_classes = """
// ─────────────────────────────────────────────────────────────────────────────
// NEW 5-LAYER HOME SCREEN COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _VisualCategoriesList extends StatelessWidget {
  final Function(String) onCategorySelected;
  
  const _VisualCategoriesList({required this.onCategorySelected});
  
  @override
  Widget build(BuildContext context) {
    final categories = [
      {'name': 'Mobile Apps', 'icon': Icons.phone_android_rounded, 'color': const Color(0xFF3B82F6)},
      {'name': 'Video Editing', 'icon': Icons.video_collection_rounded, 'color': const Color(0xFFEF4444)},
      {'name': 'Web Dev', 'icon': Icons.web_rounded, 'color': const Color(0xFF8B5CF6)},
      {'name': 'UI Design', 'icon': Icons.brush_rounded, 'color': const Color(0xFF10B981)},
      {'name': 'Backend', 'icon': Icons.dns_rounded, 'color': const Color(0xFFF59E0B)},
      {'name': 'SEO', 'icon': Icons.trending_up_rounded, 'color': const Color(0xFFEC4899)},
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text('Explore Categories', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark)),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final color = cat['color'] as Color;
              return GestureDetector(
                onTap: () {
                  // Wait for the tap ripple then navigate to all services with filter
                  Future.delayed(const Duration(milliseconds: 200), () {
                    onCategorySelected(cat['name'] as String);
                  });
                },
                child: Container(
                  width: 95,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: context.isDarkMode ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(cat['icon'] as IconData, color: color, size: 32),
                      const SizedBox(height: 12),
                      Text(
                        cat['name'] as String,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.themeTextDark),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HorizontalGigList extends StatelessWidget {
  final List<GigModel> gigs;
  final String title;
  
  const _HorizontalGigList({required this.gigs, required this.title});
  
  @override
  Widget build(BuildContext context) {
    if (gigs.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark)),
        ),
        SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: gigs.length,
            itemBuilder: (context, index) {
              final gig = gigs[index];
              final slug = gig.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(
                  width: 170,
                  child: GigCard(
                    gig: gig, 
                    onTap: () {
                      if (kIsWeb) context.go('/gig/${gig.id}/$slug');
                      else context.push('/gig/${gig.id}/$slug');
                    }
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LargeHorizontalGigList extends StatelessWidget {
  final List<GigModel> gigs;
  final String title;
  
  const _LargeHorizontalGigList({required this.gigs, required this.title});
  
  @override
  Widget build(BuildContext context) {
    if (gigs.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark)),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: gigs.length,
            itemBuilder: (context, index) {
              final gig = gigs[index];
              final slug = gig.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(
                  width: 280,
                  child: GigCard(
                    gig: gig, 
                    onTap: () {
                      if (kIsWeb) context.go('/gig/${gig.id}/$slug');
                      else context.push('/gig/${gig.id}/$slug');
                    }
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WishlistGigsSection extends StatelessWidget {
  final List<GigModel> allGigs;
  
  const _WishlistGigsSection({required this.allGigs});
  
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final savedGigIds = List<String>.from(data['savedGigs'] ?? []);
        
        if (savedGigIds.isEmpty) return const SizedBox.shrink();
        
        final savedGigs = allGigs.where((g) => savedGigIds.contains(g.id)).toList();
        if (savedGigs.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text('Your Saved Services', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark)),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: savedGigs.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 220,
              ),
              itemBuilder: (context, i) {
                final gig = savedGigs[i];
                final slug = gig.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
                return GigCard(
                  gig: gig,
                  onTap: () {
                    if (kIsWeb) context.go('/gig/${gig.id}/$slug');
                    else context.push('/gig/${gig.id}/$slug');
                  },
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}
"""

if "_VisualCategoriesList" not in content:
    content = content + new_classes

# 2. Replace _buildMobileLayout entirely
# Find the start and end of _buildMobileLayout
start_idx = content.find("  Widget _buildMobileLayout(")
# Find the next method/class which is usually class _CategoryChipsList or something similar
end_idx = content.find("class _CategoryChipsList", start_idx)

old_method = content[start_idx:end_idx]

new_method = """  Widget _buildMobileLayout(
    BuildContext context,
    ap.AuthProvider auth,
    GigProvider gigProv,
    SettingsProvider settings,
    List<GigModel> displayedGigs,
    bool showMoreButton,
  ) {
    // We get all gigs for the specific categories
    final allGigs = gigProv.gigs;
    
    final videoEditingGigs = allGigs.where((g) => g.title.toLowerCase().contains('video') || g.title.toLowerCase().contains('edit')).take(6).toList();
    final appDevelopmentGigs = allGigs.where((g) => g.title.toLowerCase().contains('app') || g.title.toLowerCase().contains('mobile')).take(6).toList();
    final popularGigs = allGigs.take(4).toList();

    return Scaffold(
      backgroundColor: context.themeBackground,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 800));
          },
          child: CustomScrollView(
            slivers: [
              // ── App Bar ─────────────────────────────────────────
              _MobileAppBar(auth: auth, settings: settings),

              // ── Hero Banner ─────────────────────────────────────
              SliverToBoxAdapter(
                child: _HeroBanner(
                  settings: settings, 
                  auth: auth,
                  onExploreTap: () {
                    context.go('/all-services');
                  },
                ),
              ),

              // ── Search Bar ──────────────────────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _SearchBarDelegate(
                  gigs: allGigs,
                  isLoading: gigProv.loading,
                ),
              ),

              // ── 5-LAYER HOME SCREEN SECTIONS ───────────────────
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Layer 1: Top Categories (Square Cards)
                    _VisualCategoriesList(
                      onCategorySelected: (category) {
                        context.go('/all-services');
                        // In a real app we'd pass the category filter to the all-services page
                      },
                    ),
                    
                    // Layer 2: Video Editing (Horizontal)
                    _HorizontalGigList(
                      title: 'Video Editing',
                      gigs: videoEditingGigs,
                    ),
                  ],
                ),
              ),

              // Layer 3 Header: Popular Services
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Text('Popular Services', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                ),
              ),

              // Layer 3: Popular Services Grid (2-Column)
              if (gigProv.loading)
                const SliverToBoxAdapter(child: _SkeletonGrid())
              else if (popularGigs.isEmpty)
                const SliverToBoxAdapter(child: _EmptyGigs())
              else
                _GigGridSliver(gigs: popularGigs),

              // Show More Button for Layer 3
              if (!gigProv.loading && allGigs.length > 4)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.go('/all-services'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: Text(
                          'Show More Services', 
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary)
                        ),
                      ),
                    ),
                  ),
                ),

              // Layer 4 & 5
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Layer 4: Mobile App Development (Large Cards)
                    _LargeHorizontalGigList(
                      title: 'Mobile App Development',
                      gigs: appDevelopmentGigs,
                    ),
                    
                    // Layer 5: Wishlist / Saved Gigs
                    _WishlistGigsSection(allGigs: allGigs),
                    
                    const SizedBox(height: 40), // Bottom padding
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

"""

content = content.replace(old_method, new_method)

with open('lib/screens/home_screen.dart', 'w') as f:
    f.write(content)

print("Updated _buildMobileLayout and added components")
