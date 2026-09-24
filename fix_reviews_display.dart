import 'dart:io';

void main() {
  final file = File('lib/screens/gig_detail_screen.dart');
  var content = file.readAsStringSync();
  
  // 1. Add star rating header below title
  final oldTitle = '''
                          Text(gig.title, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: context.themeTextDark, height: 1.2)),
                          const SizedBox(height: 16),
''';
  final newTitle = '''
                          Text(gig.title, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: context.themeTextDark, height: 1.2)),
                          const SizedBox(height: 8),
                          if (gig.reviewCount > 0)
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                                const SizedBox(width: 4),
                                Text(gig.averageRating.toStringAsFixed(1), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: context.themeTextDark)),
                                const SizedBox(width: 4),
                                Text('(\${gig.reviewCount} reviews)', style: GoogleFonts.inter(color: context.themeTextDark.withOpacity(0.5), fontSize: 14)),
                              ],
                            ),
                          const SizedBox(height: 16),
''';

  if (content.contains(oldTitle)) {
    content = content.replaceFirst(oldTitle, newTitle);
  } else {
    print("Could not find title insertion point");
  }

  // 2. Add the Reviews Section
  final oldFooter = '''
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  if (isMobile) const SizedBox(height: 100),
''';
  final newFooter = '''
                          const SizedBox(height: 32),
                          _buildReviewsSection(context),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  if (isMobile) const SizedBox(height: 100),
''';

  if (content.contains(oldFooter)) {
    content = content.replaceFirst(oldFooter, newFooter);
  } else {
    print("Could not find footer insertion point");
  }

  // 3. Inject the _buildReviewsSection method
  final injectPos = content.lastIndexOf('}');
  final reviewsMethod = '''
  Widget _buildReviewsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reviews (\${widget.gig.reviewCount})', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.bodyLarge?.color)),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('gigId', isEqualTo: widget.gig.id)
              .where('status', isEqualTo: 'completed')
              // Note: you can't use where('publicReview', isNull: false) easily in Firestore without proper indexing and data type matching.
              // So we filter manually in memory.
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Text('No reviews yet.', style: GoogleFonts.inter(color: Colors.grey));
            }
            
            final reviews = snapshot.data!.docs.where((doc) {
              final text = doc.data() as Map<String, dynamic>;
              final review = text['publicReview'] as String?;
              return review != null && review.trim().isNotEmpty;
            }).toList();

            if (reviews.isEmpty) {
              return Text('No reviews yet.', style: GoogleFonts.inter(color: Colors.grey));
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length,
              separatorBuilder: (_, __) => Divider(height: 32, color: Colors.grey.withOpacity(0.2)),
              itemBuilder: (context, index) {
                final data = reviews[index].data() as Map<String, dynamic>;
                final name = data['userName'] ?? 'Anonymous';
                final rating = (data['overallRating'] as num?)?.toDouble() ?? 5.0;
                final text = data['publicReview'] as String;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF1BCA75).withOpacity(0.1),
                          child: Text(name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF1BCA75), fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(rating.toStringAsFixed(1), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(text, style: GoogleFonts.inter(color: Colors.grey.shade700, height: 1.5)),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
''';

  content = content.substring(0, injectPos) + reviewsMethod + '\n}';
  file.writeAsStringSync(content);
}
