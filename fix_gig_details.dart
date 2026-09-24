import 'dart:io';

void main() {
  final file = File('lib/screens/gig_detail_screen.dart');
  var content = file.readAsStringSync();
  
  // Find the first _buildReviewsSection (the bad one injected inside _FiverrPricingTabs or similar)
  // Let's just remove the first one that has `BuildContext context)` instead of `BuildContext context, GigModel gig)`
  final badStart = content.indexOf('Widget _buildReviewsSection(BuildContext context) {');
  if (badStart != -1) {
     final endBad = content.indexOf('  }\n', badStart) + 4;
     // Actually the method is quite long. Let's find the end of it by counting braces or just find the next Widget or class.
     final nextWidget = content.indexOf('class ', badStart);
     final nextMethod = content.indexOf('Widget _buildReviewsSection(BuildContext context, GigModel gig)', badStart);
     if (nextMethod != -1) {
        content = content.substring(0, badStart) + content.substring(nextMethod);
        file.writeAsStringSync(content);
        print('Removed bad _buildReviewsSection');
     }
  } else {
     print('Could not find bad _buildReviewsSection');
  }
}
