import re

with open('lib/screens/profile_screen.dart', 'r') as f:
    content = f.read()

# Mobile and Desktop layouts have the exact same logic
old_rate = """                try {
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
                }"""

new_rate = """                try {
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
                }"""

if old_rate in content:
    content = content.replace(old_rate, new_rate)
    with open('lib/screens/profile_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed Rate Us logic")
else:
    print("Could not find Rate Us block")
