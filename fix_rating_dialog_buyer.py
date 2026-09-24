import re

with open('lib/screens/my_orders_screen.dart', 'r') as f:
    content = f.read()

# Replace the submission logic in RatingDialog
old_submit = """                    // 1. Update Order
                    await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({
                      'status': 'completed',
                      'hasReview': true,
                      'completedAt': FieldValue.serverTimestamp(),
                      'ratingCommunication': comms,
                      'ratingQuality': quality,
                      'ratingDescribed': described,
                      'overallRating': overall,
                      'publicReview': publicCtrl.text.trim(),
                      'privateFeedback': privateCtrl.text.trim(),
                    });

                    // 2. Add Review to Subcollection
                    final user = FirebaseAuth.instance.currentUser;
                    final gigRef = FirebaseFirestore.instance.collection('services').doc(widget.order.gigId);
                    await gigRef.collection('reviews').add({
                      'orderId': widget.order.id,
                      'userId': user?.uid ?? '',
                      'userName': user?.displayName ?? 'Client',
                      'userImage': user?.photoURL ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(user?.displayName ?? "Client")}',
                      'rating': overall,
                      'comment': publicCtrl.text.trim(),
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    // 3. Fetch all reviews and update Parent Gig
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

                    if (mounted) Navigator.pop(context);"""

new_submit = """                    final user = FirebaseAuth.instance.currentUser;
                    
                    // 1. Update Order with buyerReview (Blind Review System)
                    await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({
                      'status': 'completed',
                      'hasReview': true,
                      'isReviewPublic': false, // Hidden until seller reviews
                      'completedAt': FieldValue.serverTimestamp(),
                      'buyerReview': {
                        'userId': user?.uid ?? '',
                        'userName': user?.displayName ?? 'Client',
                        'userImage': user?.photoURL ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(user?.displayName ?? "Client")}',
                        'rating': overall,
                        'ratingCommunication': comms,
                        'ratingQuality': quality,
                        'ratingDescribed': described,
                        'comment': publicCtrl.text.trim(),
                        'privateFeedback': privateCtrl.text.trim(),
                        'createdAt': FieldValue.serverTimestamp(),
                      }
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      // Show Confetti Success Dialog
                      showDialog(
                        context: context,
                        builder: (c) => const ReviewSuccessDialog(),
                      );
                    }"""
content = content.replace(old_submit, new_submit)

with open('lib/screens/my_orders_screen.dart', 'w') as f:
    f.write(content)

print("Updated RatingDialog for Blind Review")
