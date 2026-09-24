import re

with open('lib/screens/profile_screen.dart', 'r') as f:
    content = f.read()

old_logic = """              onTap: () async {
                try {
                  final InAppReview inAppReview = InAppReview.instance;
                  // Try to show in-app review dialog first
                  if (await inAppReview.isAvailable()) {
                    await inAppReview.requestReview();
                  }
                  
                  // In TestFlight or some environments, requestReview silently fails.
                  // As a fallback, we can also try to open the store listing directly.
                  // We'll wait a bit and if they want they can be directed to the store.
                  // But standard practice: if it's not available, just open store listing.
                  if (!await inAppReview.isAvailable()) {
                    await inAppReview.openStoreListing(appStoreId: '6670553038');
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rate Us feature is currently unavailable.')),
                  );
                }
              },"""

new_logic = """              onTap: () async {
                try {
                  final InAppReview inAppReview = InAppReview.instance;
                  if (await inAppReview.isAvailable()) {
                    await inAppReview.requestReview();
                  } else {
                    await inAppReview.openStoreListing(appStoreId: '6670553038');
                  }
                } catch (e) {
                  try {
                    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
                    final url = Uri.parse(
                      isAndroid 
                          ? 'market://details?id=com.reskindevdotcom.reskindev'
                          : 'https://apps.apple.com/app/id6670553038'
                    );
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      final webUrl = Uri.parse(
                        isAndroid
                            ? 'https://play.google.com/store/apps/details?id=com.reskindevdotcom.reskindev'
                            : 'https://apps.apple.com/app/id6670553038'
                      );
                      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                    }
                  } catch (e2) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open store listing.')),
                      );
                    }
                  }
                }
              },"""

content = content.replace(old_logic, new_logic)

with open('lib/screens/profile_screen.dart', 'w') as f:
    f.write(content)

print("Fixed Rate Us logic")
