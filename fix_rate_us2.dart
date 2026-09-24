import 'dart:io';

void main() {
  final file = File('lib/screens/profile_screen.dart');
  var content = file.readAsStringSync();
  
  final oldOnTap = '''
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

  final newOnTap = '''
              onTap: () async {
                try {
                  final InAppReview inAppReview = InAppReview.instance;
                  if (await inAppReview.isAvailable()) {
                    await inAppReview.requestReview();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('App Store link is not available on the Simulator or before publish.')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rate Us feature is currently unavailable.')),
                  );
                }
              },
''';

  content = content.replaceAll(oldOnTap, newOnTap);
  file.writeAsStringSync(content);
}
