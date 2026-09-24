import 'dart:io';

void main() {
  final file = File('lib/screens/gig_editor_screen.dart');
  var content = file.readAsStringSync();
  
  // Add import if not present
  if (!content.contains('in_app_review.dart')) {
    content = content.replaceFirst(
      "import 'package:flutter/material.dart';",
      "import 'package:flutter/material.dart';\nimport 'package:in_app_review/in_app_review.dart';"
    );
  }

  final oldSaveSuccess = '''
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service saved successfully!'), backgroundColor: AppTheme.primary),
      );
''';

  final newSaveSuccess = '''
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service saved successfully!'), backgroundColor: AppTheme.primary),
      );
      
      // Request review if it's a new gig creation
      if (widget.gig == null) {
        try {
          final InAppReview inAppReview = InAppReview.instance;
          if (await inAppReview.isAvailable()) {
            await inAppReview.requestReview();
          }
        } catch (e) {
          debugPrint('InAppReview error: \$e');
        }
      }
''';

  content = content.replaceAll(oldSaveSuccess, newSaveSuccess);
  file.writeAsStringSync(content);
}
