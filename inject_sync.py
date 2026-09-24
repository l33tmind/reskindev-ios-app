import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

sync_func = """
  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _syncRatingsOneTime();
  }

  bool _hasSynced = false;
  Future<void> _syncRatingsOneTime() async {
    if (_hasSynced) return;
    _hasSynced = true;
    try {
      final servicesSnap = await FirebaseFirestore.instance.collection('services').get();
      for (var gigDoc in servicesSnap.docs) {
        final reviewsSnap = await gigDoc.reference.collection('reviews').get();
        if (reviewsSnap.docs.isNotEmpty) {
          double totalRating = 0;
          for (var rev in reviewsSnap.docs) {
            totalRating += (rev.data()['rating'] as num?)?.toDouble() ?? 5.0;
            
            // Also try to fix the order document if possible
            final orderId = rev.data()['orderId'] as String?;
            if (orderId != null) {
              await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
                'overallRating': (rev.data()['rating'] as num?)?.toDouble() ?? 5.0,
                'publicReview': rev.data()['comment'] ?? 'Great service!',
              }, SetOptions(merge: true));
            }
          }
          final avg = totalRating / reviewsSnap.docs.length;
          await gigDoc.reference.update({
            'rating': avg,
            'averageRating': avg,
            'reviewCount': reviewsSnap.docs.length,
          });
        }
      }
      debugPrint("Ratings synced successfully!");
    } catch (e) {
      debugPrint("Error syncing ratings: $e");
    }
  }
"""

# Replace the initState
old_init = """  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }"""

if old_init in content:
    content = content.replace(old_init, sync_func)
    with open('lib/screens/home_screen.dart', 'w') as f:
        f.write(content)
    print("Injected sync function into home_screen.dart")
else:
    print("Could not find initState in home_screen.dart")
