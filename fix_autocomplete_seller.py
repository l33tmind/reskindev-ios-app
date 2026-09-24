import re

with open('lib/screens/seller_dashboard_screen.dart', 'r') as f:
    content = f.read()

old_state = """class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  String _ordersFilter = 'all';"""
new_state = """class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  String _ordersFilter = 'all';
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

old_build = """      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error loading orders. Please try again.', style: GoogleFonts.inter(color: Colors.red))));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final allOrders = snapshot.data!.docs.map((d) => OrderModel.fromFirestore(d)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));"""

new_build = """      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error loading orders. Please try again.', style: GoogleFonts.inter(color: Colors.red))));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final allOrders = snapshot.data!.docs.map((d) => OrderModel.fromFirestore(d)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
        if (!_checkedAutoCompletes && allOrders.isNotEmpty) {
          _checkedAutoCompletes = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkAutoCompletes(allOrders);
          });
        }"""
content = content.replace(old_build, new_build)

with open('lib/screens/seller_dashboard_screen.dart', 'w') as f:
    f.write(content)

print("Added Auto-Complete to Seller Dashboard")
