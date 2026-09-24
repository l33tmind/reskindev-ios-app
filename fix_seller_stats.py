import re

with open('lib/screens/seller_profile_screen.dart', 'r') as f:
    content = f.read()

old_stats = """  Future<void> _fetchSellerStats() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('authorId', isEqualTo: widget.sellerId)
          .where('status', isEqualTo: 'completed')
          .get();

      int orders = snap.docs.length;
      double totalRating = 0.0;
      int reviews = 0;

      for (var doc in snap.docs) {"""

new_stats = """  Future<void> _fetchSellerStats() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('authorId', isEqualTo: widget.sellerId)
          .get();
          
      final completedDocs = snap.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'completed';
      }).toList();

      int orders = completedDocs.length;
      double totalRating = 0.0;
      int reviews = 0;

      for (var doc in completedDocs) {"""

if old_stats in content:
    content = content.replace(old_stats, new_stats)
    with open('lib/screens/seller_profile_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed stats indexes")
else:
    print("Could not find old stats")
