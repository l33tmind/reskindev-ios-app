with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

web_classes = """
// ─────────────────────────────────────────────────────────────────────────────
// WEB COMPONENTS PLACEHOLDERS (Recovered)
// ─────────────────────────────────────────────────────────────────────────────
class _WebHeroSection extends StatelessWidget {
  final SettingsProvider settings;
  const _WebHeroSection({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Premium App Development',
              style: GoogleFonts.outfit(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Hire expert developers to bring your ideas to life.',
              style: GoogleFonts.inter(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _WebSearchAndFilter extends StatelessWidget {
  final List<GigModel> gigs;
  final bool isLoading;
  final bool showAll;
  final ValueChanged<bool> onShowAllChanged;

  const _WebSearchAndFilter({
    required this.gigs,
    required this.isLoading,
    required this.showAll,
    required this.onShowAllChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _SkeletonGrid();
    }
    if (gigs.isEmpty) {
      return const _EmptyGigs();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
            mainAxisExtent: 220,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: showAll ? gigs.length : (gigs.length > 8 ? 8 : gigs.length),
          itemBuilder: (context, i) {
            final gig = gigs[i];
            final slug = gig.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
            return GigCard(
              gig: gig,
              onTap: () {
                context.go('/gig/${gig.id}/$slug');
              },
            );
          },
        ),
        if (!showAll && gigs.length > 8)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Center(
              child: ElevatedButton(
                onPressed: () => onShowAllChanged(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text('Load More Services', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ],
    );
  }
}
"""

content += web_classes

with open('lib/screens/home_screen.dart', 'w') as f:
    f.write(content)

print("Added web classes")
