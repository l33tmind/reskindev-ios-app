import 'dart:io';

void main() {
  final file = File('lib/screens/gig_detail_screen.dart');
  var content = file.readAsStringSync();
  
  final methodStr = '''
  Widget _buildSellerProfile(BuildContext context, GigModel gig) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: context.themeCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.themeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About the Seller', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.themeTextDark)),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: Text(gig.authorName.isNotEmpty ? gig.authorName[0].toUpperCase() : 'S', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gig.authorName.isNotEmpty ? gig.authorName : 'Verified Seller', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: context.themeTextDark)),
                    const SizedBox(height: 4),
                    Text('Tap to view profile & past work', style: GoogleFonts.inter(color: AppTheme.primary, fontSize: 13)),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => context.push('/seller-profile/\${gig.authorId}'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('View Profile'),
              )
            ],
          ),
        ],
      ),
    );
  }
''';

  if (!content.contains('_buildSellerProfile')) {
    content = content.replaceFirst('  Widget _buildReviewsSection', methodStr + '\n  Widget _buildReviewsSection');
    content = content.replaceAll('_buildReviewsSection(context, gig)', '_buildSellerProfile(context, gig),\n                          _buildReviewsSection(context, gig)');
    print("Added Seller Profile section to gig_detail_screen");
  }

  file.writeAsStringSync(content);
}
