import re

with open('lib/widgets/workspace_timeline_modals.dart', 'r') as f:
    c = f.read()

# 1. Add _StarRating class if not exists
star_class = """
class _StarRating extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRatingChanged;
  const _StarRating({required this.rating, required this.onRatingChanged});
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () => onRatingChanged(index + 1),
          child: Padding(
            padding: const EdgeInsets.only(right: 2.0),
            child: Icon(
              Icons.star_rounded,
              size: 28,
              color: (index < rating) ? Colors.amber : Colors.grey.shade300,
            ),
          ),
        );
      }),
    );
  }
}

"""

if "_StarRating" not in c:
    # insert before class WorkspaceTimelineModals
    c = c.replace("class WorkspaceTimelineModals {", star_class + "class WorkspaceTimelineModals {")


# 2. Rewrite showAcceptDelivery
old_accept = r"static void showAcceptDelivery\(BuildContext context, OrderModel order, String chatId\) \{.*?child: const Text\('Accept & Submit'\),\s*\),\s*\],\s*\),\s*\);\s*\},\s*\);\s*\}"

new_accept = """static void showAcceptDelivery(BuildContext context, OrderModel order, String chatId) {
    int commRating = 5;
    int serviceRating = 5;
    bool recommend = true;
    final ctrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder: (context, setState) {
            final calculatedRating = ((commRating + serviceRating) / 2);
            return AlertDialog(
            title: Text('Accept & Review', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
                      const SizedBox(width: 8),
                      Text(calculatedRating.toStringAsFixed(1), style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text('(Calculated)', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Communication', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  _StarRating(rating: commRating, onRatingChanged: (v) => setState(() => commRating = v)),
                  const SizedBox(height: 12),
                  Text('Service as Described', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  _StarRating(rating: serviceRating, onRatingChanged: (v) => setState(() => serviceRating = v)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Would you recommend?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      Switch(
                        value: recommend,
                        activeColor: AppTheme.primary,
                        onChanged: (v) => setState(() => recommend = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Write a public review (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(c);
                  Navigator.pop(context); // Close BottomSheet
                  
                  final reviewMap = {
                    'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
                    'userName': FirebaseAuth.instance.currentUser?.displayName ?? 'Client',
                    'userImage': FirebaseAuth.instance.currentUser?.photoURL ?? '',
                    'rating': calculatedRating,
                    'communication': commRating,
                    'service': serviceRating,
                    'recommend': recommend,
                    'comment': ctrl.text.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                  };
                  
                  await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                    'status': 'completed',
                    'completedAt': FieldValue.serverTimestamp(),
                    'buyerReview': reviewMap,
                    'rating': calculatedRating,
                    'isReviewPublic': false,
                    'hasReview': true,
                  });
                  
                  await Provider.of<ChatProvider>(context, listen: false).sendSystemMessage(
                    orderId: order.id!,
                    buyerId: order.userId,
                    buyerName: order.userName,
                    sellerId: order.authorId,
                    sellerName: 'Seller',
                    gigTitle: order.gigTitle,
                    actionType: 'order_completed',
                    text: 'The buyer has accepted the delivery and payment has been transferred!',
                  );
                },
                child: const Text('Accept & Submit'),
              ),
            ],
          );
          },
        );
      },
    );
  }"""

c = re.sub(old_accept, new_accept, c, flags=re.DOTALL)

old_seller = r"static void showSellerReview\(BuildContext context, OrderModel order, String chatId\) \{.*?child: const Text\('Submit Review'\),\s*\),\s*\],\s*\),\s*\);\s*\},\s*\);\s*\}"

new_seller = """static void showSellerReview(BuildContext context, OrderModel order, String chatId) {
    int commRating = 5;
    int serviceRating = 5;
    bool recommend = true;
    final ctrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder: (context, setState) {
            final calculatedRating = ((commRating + serviceRating) / 2);
            return AlertDialog(
            title: Text('Rate Buyer', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
                      const SizedBox(width: 8),
                      Text(calculatedRating.toStringAsFixed(1), style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text('(Calculated)', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Communication', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  _StarRating(rating: commRating, onRatingChanged: (v) => setState(() => commRating = v)),
                  const SizedBox(height: 12),
                  Text('Working Experience', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  _StarRating(rating: serviceRating, onRatingChanged: (v) => setState(() => serviceRating = v)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Would you recommend?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      Switch(
                        value: recommend,
                        activeColor: AppTheme.primary,
                        onChanged: (v) => setState(() => recommend = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Write a public review (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(c);
                  Navigator.pop(context); // Close BottomSheet
                  
                  final reviewMap = {
                    'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
                    'userName': FirebaseAuth.instance.currentUser?.displayName ?? 'Seller',
                    'userImage': FirebaseAuth.instance.currentUser?.photoURL ?? '',
                    'rating': calculatedRating,
                    'communication': commRating,
                    'service': serviceRating,
                    'recommend': recommend,
                    'comment': ctrl.text.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                  };
                  
                  await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                    'sellerReview': reviewMap,
                  });
                  
                  await Provider.of<ChatProvider>(context, listen: false).sendSystemMessage(
                    orderId: order.id!,
                    buyerId: order.userId,
                    buyerName: order.userName,
                    sellerId: order.authorId,
                    sellerName: 'Seller',
                    gigTitle: order.gigTitle,
                    actionType: 'review',
                    text: 'The seller has reviewed the buyer!',
                  );
                },
                child: const Text('Submit Review'),
              ),
            ],
          );
          },
        );
      },
    );
  }"""

c = re.sub(old_seller, new_seller, c, flags=re.DOTALL)

with open('lib/widgets/workspace_timeline_modals.dart', 'w') as f:
    f.write(c)

