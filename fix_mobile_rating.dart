import 'dart:io';

void main() {
  final file = File('lib/screens/gig_detail_screen.dart');
  var content = file.readAsStringSync();
  
  final oldMobileTitle = '''
                Text(
                  gig.title,
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: context.themeTextDark, height: 1.2),
                ),
                const SizedBox(height: 16),
''';

  final newMobileTitle = '''
                Text(
                  gig.title,
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: context.themeTextDark, height: 1.2),
                ),
                const SizedBox(height: 12),
                if (gig.reviewCount > 0)
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(gig.averageRating.toStringAsFixed(1), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: context.themeTextDark)),
                      const SizedBox(width: 4),
                      Text('(\${gig.reviewCount} reviews)', style: GoogleFonts.inter(color: context.themeTextLight, fontSize: 13)),
                    ],
                  ),
                const SizedBox(height: 16),
''';

  if (content.contains(oldMobileTitle)) {
    content = content.replaceFirst(oldMobileTitle, newMobileTitle);
    print('Updated mobile title');
  } else {
    print('Could not find mobile title');
  }

  final oldMobileEnd = '''
                  _FiverrPricingTabs(
                    gig: gig,
                    selectedPackage: _selectedPackage,
                    onPackageSelected: (pkgName) {
                      setState(() {
                        _selectedPackage = pkgName;
                      });
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
''';

  final newMobileEnd = '''
                  _FiverrPricingTabs(
                    gig: gig,
                    selectedPackage: _selectedPackage,
                    onPackageSelected: (pkgName) {
                      setState(() {
                        _selectedPackage = pkgName;
                      });
                    },
                  ),
                const SizedBox(height: 24),
                _buildReviewsSection(context, gig),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
''';

  if (content.contains(oldMobileEnd)) {
    content = content.replaceFirst(oldMobileEnd, newMobileEnd);
    print('Updated mobile end');
  } else {
    print('Could not find mobile end');
  }

  file.writeAsStringSync(content);
}
