import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/order_model.dart';
import '../providers/chat_provider.dart';


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
class WorkspaceActionModals {
  static void showSubmitRequirements(BuildContext context, OrderModel order, String chatId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Submit Requirements', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Provide details about your project...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(c);
              Navigator.pop(context); // Close the BottomSheet too
              
              await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                'status': 'processing',
                'projectDetails': ctrl.text.trim(), 'requirementsText': ctrl.text.trim(),
                'startedAt': FieldValue.serverTimestamp(),
              });
              
              await Provider.of<ChatProvider>(context, listen: false).sendSystemMessage(
                orderId: order.id!,
                buyerId: order.userId,
                buyerName: order.userName,
                sellerId: order.authorId,
                sellerName: 'Seller',
                gigTitle: order.gigTitle,
                actionType: 'requirements_submitted',
                text: 'The buyer has submitted the requirements.\n\n${ctrl.text.trim()}',
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  static void showDeliverWork(BuildContext context, OrderModel order, String chatId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Deliver Work', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Provide links to files or write a delivery note...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(c);
              Navigator.pop(context); // Close the BottomSheet too
              
              await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                'status': 'delivered',
                'deliveryNote': ctrl.text.trim(),
                'deliveredAt': FieldValue.serverTimestamp(),
              });
              
              await Provider.of<ChatProvider>(context, listen: false).sendSystemMessage(
                orderId: order.id!,
                buyerId: order.userId,
                buyerName: order.userName,
                sellerId: order.authorId,
                sellerName: 'Seller',
                gigTitle: order.gigTitle,
                actionType: 'order_delivered',
                text: ctrl.text.trim(),
              );
            },
            child: const Text('Deliver'),
          ),
        ],
      ),
    );
  }

  static void showRevision(BuildContext context, OrderModel order, String chatId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Request Revision', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'What needs to be changed?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(c);
              Navigator.pop(context); // Close the BottomSheet too
              
              await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                'status': 'revision',
                'revisionNote': ctrl.text.trim(),
              });
              
              await Provider.of<ChatProvider>(context, listen: false).sendSystemMessage(
                orderId: order.id!,
                buyerId: order.userId,
                buyerName: order.userName,
                sellerId: order.authorId,
                sellerName: 'Seller',
                gigTitle: order.gigTitle,
                actionType: 'revision_requested',
                text: ctrl.text.trim(),
              );
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  static void showAcceptDelivery(BuildContext context, OrderModel order, String chatId) {
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
                        activeThumbColor: AppTheme.primary,
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
                    metadata: {
                      'rating': calculatedRating,
                      'comment': ctrl.text.trim(),
                    },
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
  }

  static void showSellerReview(BuildContext context, OrderModel order, String chatId) {
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
                        activeThumbColor: AppTheme.primary,
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
  }
}
