import re

with open('lib/screens/my_orders_screen.dart', 'r') as f:
    content = f.read()

old_block = """                    // 1. Update Order
                    await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({
                      'status': 'completed',
                      'completedAt': FieldValue.serverTimestamp(),
                      'ratingCommunication': comms,
                      'ratingQuality': quality,
                      'ratingDescribed': described,
                      'overallRating': overall,
                      'publicReview': publicCtrl.text.trim(),
                      'privateFeedback': privateCtrl.text.trim(),
                    });

                    // 2. Update Gig aggregates
                    final gigRef = FirebaseFirestore.instance.collection('services').doc(widget.order.gigId);
                    await FirebaseFirestore.instance.runTransaction((tx) async {
                      final doc = await tx.get(gigRef);
                      if (doc.exists) {
                        final currentCount = (doc.data()?['reviewCount'] as num?)?.toInt() ?? 0;
                        final currentAvg = (doc.data()?['averageRating'] as num?)?.toDouble() ?? 0.0;
                        
                        final newCount = currentCount + 1;
                        final newAvg = ((currentAvg * currentCount) + overall) / newCount;
                        
                        tx.update(gigRef, {
                          'reviewCount': newCount,
                          'averageRating': newAvg,
                        });
                      }
                    });"""

new_block = """                    // 1. Update Order
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
                      final newAvg = totalRating / reviewsSnap.docs.length;
                      
                      await gigRef.update({
                        'reviewCount': reviewsSnap.docs.length,
                        'rating': newAvg,
                        'averageRating': newAvg,
                      });
                    }"""

if old_block in content:
    content = content.replace(old_block, new_block)
    # Also add firebase_auth import if it's not there, but it probably is in my_orders_screen.dart
    if "import 'package:firebase_auth/firebase_auth.dart';" not in content:
        content = content.replace("import 'package:cloud_firestore/cloud_firestore.dart';", "import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'package:firebase_auth/firebase_auth.dart';")
    with open('lib/screens/my_orders_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed MyOrdersScreen")
else:
    print("Could not find block in MyOrdersScreen")
