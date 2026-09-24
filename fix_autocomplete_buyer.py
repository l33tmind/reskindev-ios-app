import re

with open('lib/screens/my_orders_screen.dart', 'r') as f:
    content = f.read()

# Add flag to state
old_state = """class _MyOrdersScreenState extends State<MyOrdersScreen> {
  String _filterStatus = 'all';"""
new_state = """class _MyOrdersScreenState extends State<MyOrdersScreen> {
  String _filterStatus = 'all';
  bool _checkedAutoCompletes = false;

  void _checkAutoCompletes(List<OrderModel> orders) async {
    final now = DateTime.now();
    for (var order in orders) {
      if (order.status == 'delivered' && order.deliveredAt != null) {
        if (now.difference(order.deliveredAt!).inDays >= 3) {
          final systemReview = {
            'userId': 'system',
            'userName': 'System (Auto-Completed)',
            'userImage': 'https://ui-avatars.com/api/?name=System',
            'rating': 5.0,
            'ratingCommunication': 5.0,
            'ratingQuality': 5.0,
            'ratingDescribed': 5.0,
            'comment': 'Order automatically completed after 3 days of delivery.',
            'createdAt': FieldValue.serverTimestamp(),
          };
          
          await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
            'hasReview': true,
            'isReviewPublic': true,
            'buyerReview': systemReview,
            'sellerReview': systemReview,
          });
          
          final gigRef = FirebaseFirestore.instance.collection('services').doc(order.gigId);
          await gigRef.collection('reviews').add({
            'orderId': order.id,
            ...systemReview
          });
          
          final reviewsSnap = await gigRef.collection('reviews').get();
          if (reviewsSnap.docs.isNotEmpty) {
            double totalRating = 0;
            for (var r in reviewsSnap.docs) {
              totalRating += (r.data()['rating'] as num?)?.toDouble() ?? 5.0;
            }
            final avgRating = totalRating / reviewsSnap.docs.length;
            await gigRef.update({
              'rating': avgRating,
              'reviewCount': reviewsSnap.docs.length,
            });
          }
        }
      }
    }
  }"""
content = content.replace(old_state, new_state)

old_build = """          final allOrders = (snap.data?.docs ?? [])
              .map((d) => OrderModel.fromFirestore(d))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (kIsWeb) {"""

new_build = """          final allOrders = (snap.data?.docs ?? [])
              .map((d) => OrderModel.fromFirestore(d))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (!_checkedAutoCompletes && allOrders.isNotEmpty) {
            _checkedAutoCompletes = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkAutoCompletes(allOrders);
            });
          }

          if (kIsWeb) {"""
content = content.replace(old_build, new_build)

with open('lib/screens/my_orders_screen.dart', 'w') as f:
    f.write(content)

print("Added 3-Day Auto-Complete to Buyer Screen")
