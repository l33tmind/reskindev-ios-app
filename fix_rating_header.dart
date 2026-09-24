import 'dart:io';

void main() {
  final file = File('lib/screens/gig_detail_screen.dart');
  var content = file.readAsStringSync();
  
  final oldHeader = '''
                          const SizedBox(height: 4),
                          Text(
                            'Review gig features, previews, and select your custom package',
                            style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight),
                          ),
                          const SizedBox(height: 20),
''';

  final newHeader = '''
                          const SizedBox(height: 4),
                          Text(
                            'Review gig features, previews, and select your custom package',
                            style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight),
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
                          const SizedBox(height: 20),
''';

  if (content.contains(oldHeader)) {
    content = content.replaceFirst(oldHeader, newHeader);
    file.writeAsStringSync(content);
    print('Added rating to desktop header');
  } else {
    print('Could not find desktop header');
  }
}
