import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

target = """class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';
  double _maxPrice = 5000;
  String _sortBy = 'default';
  bool _showAll = false;
  final GlobalKey _servicesKey = GlobalKey();"""

replacement = """class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';
  double _maxPrice = 5000;
  String _sortBy = 'default';
  bool _showAll = false;
  final GlobalKey _servicesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
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
  }"""

if target in content:
    content = content.replace(target, replacement)
    with open('lib/screens/home_screen.dart', 'w') as f:
        f.write(content)
    print("Injected sync function into home_screen.dart")
else:
    print("Could not find target in home_screen.dart")
