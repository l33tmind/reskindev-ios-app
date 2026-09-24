import 'dart:io';

void main() {
  final file = File('lib/screens/gig_detail_screen.dart');
  var content = file.readAsStringSync();
  
  final oldLeftColumnEnd = '''
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
''';

  final newLeftColumnEnd = '''
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildReviewsSection(context, gig),
                          const SizedBox(height: 24),
                        ],
                      );
''';

  if (content.contains(oldLeftColumnEnd)) {
    content = content.replaceFirst(oldLeftColumnEnd, newLeftColumnEnd);
  } else {
    print('Could not find leftColumn end');
  }

  // Inject the _buildReviewsSection method
  final injectPos = content.lastIndexOf('}');
  final reviewsMethod = '''
  Widget _buildReviewsSection(BuildContext context, GigModel gig) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reviews (\${gig.reviewCount})', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: context.themeTextDark)),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('gigId', isEqualTo: gig.id)
              .where('status', isEqualTo: 'completed')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Text('No reviews yet.', style: GoogleFonts.inter(color: context.themeTextLight));
            }
            
            final reviews = snapshot.data!.docs.where((doc) {
              final text = doc.data() as Map<String, dynamic>;
              final review = text['publicReview'] as String?;
              return review != null && review.trim().isNotEmpty;
            }).toList();

            if (reviews.isEmpty) {
              return Text('No reviews yet.', style: GoogleFonts.inter(color: context.themeTextLight));
            }

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.themeSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.themeBorder),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reviews.length,
                separatorBuilder: (_, __) => Divider(height: 32, color: context.themeBorder),
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
                          Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextDark)),
                          const Spacer(),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(rating.toStringAsFixed(1), style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextDark)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(text, style: GoogleFonts.inter(color: context.themeTextLight, height: 1.5)),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
''';

  content = content.substring(0, injectPos) + reviewsMethod + '\n}';
  file.writeAsStringSync(content);
  print('Added reviews section');
}
