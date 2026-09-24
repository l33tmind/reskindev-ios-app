import re

with open('lib/providers/gig_provider.dart', 'r') as f:
    content = f.read()

old_block = """  void _listen() {
    _db.collection('services').snapshots().listen((snap) {
      final docs = snap.docs.map((d) => GigModel.fromFirestore(d)).toList();
      docs.sort((a, b) => a.order.compareTo(b.order)); 
      _gigs = docs;
      _loading = false;
      notifyListeners();
    }, onError: (error) {
      debugPrint("GigProvider ERROR: $error");
      _loading = false;
      notifyListeners();
    });
  }"""

new_block = """  void _listen() {
    _db.collection('services').snapshots().listen((snap) async {
      final docs = snap.docs.map((d) => GigModel.fromFirestore(d)).toList();
      docs.sort((a, b) => a.order.compareTo(b.order)); 
      _gigs = docs;
      _loading = false;
      notifyListeners();

      // Dynamic Fallback: Check for missing ratings and calculate dynamically
      for (var gig in docs) {
        if (gig.averageRating == 0.0 && gig.reviewCount == 0) {
          try {
            final revSnap = await _db.collection('services').doc(gig.id).collection('reviews').get();
            if (revSnap.docs.isNotEmpty) {
              double total = 0;
              for (var r in revSnap.docs) {
                total += (r.data()['rating'] as num?)?.toDouble() ?? 5.0;
              }
              final avg = total / revSnap.docs.length;
              
              // Update firestore, which will trigger another snapshot event to update UI
              await _db.collection('services').doc(gig.id).update({
                'rating': avg,
                'averageRating': avg,
                'reviewCount': revSnap.docs.length,
              });
            }
          } catch (e) {
            debugPrint("Fallback rating calculation failed for ${gig.id}: $e");
          }
        }
      }
    }, onError: (error) {
      debugPrint("GigProvider ERROR: $error");
      _loading = false;
      notifyListeners();
    });
  }"""

if old_block in content:
    content = content.replace(old_block, new_block)
    with open('lib/providers/gig_provider.dart', 'w') as f:
        f.write(content)
    print("Fixed GigProvider")
else:
    print("Could not find block in GigProvider")
