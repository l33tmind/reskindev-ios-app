import 'dart:io';

void main() {
  final file = File('lib/screens/profile_screen.dart');
  var content = file.readAsStringSync();
  
  // Add import if not present
  if (!content.contains('in_app_review.dart')) {
    content = content.replaceFirst(
      "import 'package:flutter/material.dart';",
      "import 'package:flutter/material.dart';\nimport 'package:in_app_review/in_app_review.dart';"
    );
  }

  final oldOnTap = '''
              onTap: () async {
                final url = Uri.parse('https://apps.apple.com/app/id6670553038?action=write-review');
                if (await canLaunchUrl(url)) {
                  launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
''';

  final newOnTap = '''
              onTap: () async {
                try {
                  final InAppReview inAppReview = InAppReview.instance;
                  if (await inAppReview.isAvailable()) {
                    await inAppReview.requestReview();
                  } else {
                    await inAppReview.openStoreListing(appStoreId: '6802118085');
                  }
                } catch (e) {
                  // Fallback for TestFlight or invalid URL error
                  try {
                    final url = Uri.parse('https://apps.apple.com/app/id6802118085?action=write-review');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  } catch (e) {
                    debugPrint('Error launching store: \$e');
                  }
                }
              },
''';

  content = content.replaceAll(oldOnTap, newOnTap);
  file.writeAsStringSync(content);
}
