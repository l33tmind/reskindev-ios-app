import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/order_model.dart';
import '../providers/chat_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_avatar.dart';


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
        title: Text('Submit Requirements', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe what you need. Share files with a link, e.g. Google Drive or WeTransfer',
                hintMaxLines: 3,
                hintStyle: GoogleFonts.inter(fontSize: 13.5, color: context.themeTextLight),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tip: upload big files to Google Drive or WeTransfer, then paste the share link here.',
              style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight, height: 1.4),
            ),
          ],
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

  static void showDeliverWork(BuildContext context, OrderModel order, String chatId, {bool closeSheet = true}) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Deliver Work', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The buyer gets this note right away and can accept it or ask for changes.',
              style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Write a delivery note or paste a link to your files...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(c);
              if (closeSheet) Navigator.pop(context); // Close the BottomSheet too
              
              await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                'status': 'delivered',
                'deliveryNote': ctrl.text.trim(),
                'deliveredAt': FieldValue.serverTimestamp(),
                // Delivering without "Start Work" first still records when work started
                if (order.startedAt == null) 'startedAt': FieldValue.serverTimestamp(),
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

  static void showRevision(BuildContext context, OrderModel order, String chatId, {bool closeSheet = true}) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Ask for changes', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Free. The order stays open and the seller delivers again.',
              style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: context.themeTextLight)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'What should the seller change? E.g. make the logo bigger',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(c);
              if (closeSheet) Navigator.pop(context); // Close the BottomSheet too
              
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
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  /// Buyer accepts a delivery. Built to make saying "yes" feel safe: what arrived sits next to what was
  /// asked for, every consequence is spelled out, and "Ask for changes" is as easy to reach as Accept.
  static void showAcceptDelivery(BuildContext context, OrderModel order, String chatId, {bool closeSheet = true}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.themeSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => _AcceptDeliverySheet(
        order: order,
        onAskForChanges: () {
          Navigator.pop(sheetCtx);
          showRevision(context, order, chatId, closeSheet: closeSheet);
        },
        onAccept: () async {
          Navigator.pop(sheetCtx);
          if (closeSheet) Navigator.pop(context); // Close the details sheet underneath
          await _completeOrder(context, order, chatId);
        },
      ),
    );
  }

  static Future<void> _completeOrder(BuildContext context, OrderModel order, String chatId) async {
    await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    await Provider.of<ChatProvider>(context, listen: false).sendSystemMessage(
      orderId: order.id!,
      buyerId: order.userId,
      buyerName: order.userName,
      sellerId: order.authorId,
      sellerName: 'Seller',
      gigTitle: order.gigTitle,
      actionType: 'order_completed',
      text: 'The buyer has accepted the delivery and payment has been transferred!',
      price: order.price,
      metadata: {},
    );
    if (!context.mounted) return;

    // Done: celebrate first, then a light, skippable review ask
    showDialog(
      context: context,
      builder: (promptCtx) => AlertDialog(
        backgroundColor: Theme.of(promptCtx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.celebration_rounded, color: AppTheme.success, size: 40),
        title: Text('All done!',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: promptCtx.themeTextDark)),
        content: Text(
          'The order is complete and the seller has been paid. A quick review helps other buyers. '
          'It takes 20 seconds, and you can also do it later from My Orders.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 14, height: 1.45, color: promptCtx.themeTextLight),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(promptCtx),
            child: Text('Later', style: GoogleFonts.inter(color: promptCtx.themeTextLight, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(promptCtx);
              showBuyerReview(context, order, chatId);
            },
            icon: const Icon(Icons.star_rounded, size: 18),
            label: const Text('Leave a review'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }

  static void showBuyerReview(BuildContext context, OrderModel order, String chatId) {
    if (order.completedAt != null && DateTime.now().difference(order.completedAt!).inDays > 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The 15-day review period for this order has expired.')),
      );
      return;
    }

    int commRating = 5;
    int serviceRating = 5;
    int qualityRating = 5;
    bool recommend = true;
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder: (context, setState) {
            final calculatedRating = ((commRating + serviceRating + qualityRating) / 3);
            return AlertDialog(
              title: Text('Rate Your Experience', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
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
                    Text('Quality of Work', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    _StarRating(rating: qualityRating, onRatingChanged: (v) => setState(() => qualityRating = v)),
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

                    final reviewMap = {
                      'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
                      'userName': FirebaseAuth.instance.currentUser?.displayName ?? 'Client',
                      'userImage': FirebaseAuth.instance.currentUser?.photoURL ?? '',
                      'rating': calculatedRating,
                      'communication': commRating,
                      'quality': qualityRating,
                      'service': serviceRating,
                      'recommend': recommend,
                      'comment': ctrl.text.trim(),
                      'createdAt': FieldValue.serverTimestamp(),
                    };

                    final orderRef = FirebaseFirestore.instance.collection('orders').doc(order.id);
                    await orderRef.update({
                      'buyerReview': reviewMap,
                      'rating': calculatedRating,
                      'hasReview': true,
                    });

                    // If seller already reviewed (isReviewPublic is true or sellerReview exists), publish to gig
                    final updatedSnap = await orderRef.get();
                    final updatedOrder = updatedSnap.data() ?? {};
                    if (updatedOrder['isReviewPublic'] == true || updatedOrder['sellerReview'] != null) {
                      final gigRef = FirebaseFirestore.instance.collection('services').doc(order.gigId);
                      await gigRef.collection('reviews').add(reviewMap);

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

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Review submitted! Thank you.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                  child: const Text('Submit Review'),
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
    int qualityRating = 5;
    bool recommend = true;
    final ctrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder: (context, setState) {
            final calculatedRating = ((commRating + serviceRating + qualityRating) / 3);
            return AlertDialog(
            title: Text('Rate Buyer', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
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
                    'quality': qualityRating,
                    'service': serviceRating,
                    'recommend': recommend,
                    'comment': ctrl.text.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                  };
                  
                  final orderRef = FirebaseFirestore.instance.collection('orders').doc(order.id);
                  final gigRef = FirebaseFirestore.instance.collection('services').doc(order.gigId);

                  // 1. Update Order
                  await orderRef.update({
                    'sellerReview': reviewMap,
                    'isReviewPublic': true, // Reviews are now public!
                  });

                  // 2. Publish both reviews to gig's subcollection
                  if (order.buyerReview != null) {
                    await gigRef.collection('reviews').add(order.buyerReview!);
                  }

                  // 3. Update Gig Rating
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

                  // 4. Publish Seller's Review to Buyer Profile
                  if (order.clientUid != null && order.clientUid.isNotEmpty) {
                    final buyerRef = FirebaseFirestore.instance.collection('users').doc(order.clientUid);
                    
                    await buyerRef.collection('reviews').add({
                      ...reviewMap,
                      'orderId': order.id,
                      'gigTitle': order.gigTitle,
                    });
                    
                    final buyerSnap = await buyerRef.get();
                    if (buyerSnap.exists) {
                      final bData = buyerSnap.data() as Map<String, dynamic>;
                      final currentCount = (bData['reviewCount'] as num?)?.toInt() ?? 0;
                      final currentAvg = (bData['averageRating'] as num?)?.toDouble() ?? 5.0;
                      
                      final newCount = currentCount + 1;
                      final newAvg = double.parse(((currentAvg * currentCount + calculatedRating) / newCount).toStringAsFixed(1));
                      
                      await buyerRef.update({
                        'reviewCount': newCount,
                        'averageRating': newAvg,
                      });
                    }
                  }
                  
                  await Provider.of<ChatProvider>(context, listen: false).sendSystemMessage(
                    orderId: order.id!,
                    buyerId: order.userId,
                    buyerName: order.userName,
                    sellerId: order.authorId,
                    sellerName: 'Seller',
                    gigTitle: order.gigTitle,
                    actionType: 'reviews_published',
                    text: 'Both parties have submitted their reviews!',
                    metadata: {
                      'buyerRating': order.buyerReview?['rating'] ?? 0.0,
                      'buyerComment': order.buyerReview?['comment'] ?? '',
                      'sellerRating': calculatedRating,
                      'sellerComment': ctrl.text.trim(),
                    },
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


class _AcceptDeliverySheet extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onAskForChanges;
  final Future<void> Function() onAccept;

  const _AcceptDeliverySheet({required this.order, required this.onAskForChanges, required this.onAccept});

  /// The delivery link, or the first link in the note (Flutter deliveries put links in the note)
  Uri? get _filesUrl {
    final explicit = order.deliveryLink.trim();
    final candidate = explicit.isNotEmpty
        ? explicit
        : RegExp(r'https?://\S+').firstMatch(order.deliveryNote)?.group(0);
    if (candidate == null) return null;
    final uri = Uri.tryParse(candidate);
    return (uri != null && uri.hasScheme) ? uri : null;
  }

  @override
  Widget build(BuildContext context) {
    final note = order.deliveryNote.trim();
    final asked = order.projectDetails.trim();
    final files = _filesUrl;
    final autoDone = order.deliveredAt?.add(const Duration(days: 3));

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + MediaQuery.of(context).viewPadding.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: context.themeBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.inventory_2_rounded, color: AppTheme.success, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your delivery is here',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                      Text(order.gigTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. What arrived
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A face and a name: a delivery from a person feels safer than one from "the seller"
                  Row(
                    children: [
                      UserAvatar(uid: order.authorId, name: 'Seller', radius: 12),
                      const SizedBox(width: 8),
                      Flexible(
                        child: LiveUserName(
                          uid: order.authorId,
                          fallback: 'The seller',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: context.themeTextDark),
                        ),
                      ),
                      Text(' sent this', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    note.isEmpty ? 'The seller marked the work as delivered. Check the chat for files.' : note,
                    style: GoogleFonts.inter(fontSize: 14, height: 1.45, color: context.themeTextDark),
                  ),
                  if (files != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(files, mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Open the files'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.success,
                        side: BorderSide(color: AppTheme.success.withValues(alpha: 0.5)),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 2. What was asked for, to compare (folded)
            if (asked.isNotEmpty)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  iconColor: context.themeTextLight,
                  collapsedIconColor: context.themeTextLight,
                  leading: Icon(Icons.assignment_outlined, size: 20, color: context.themeTextLight),
                  title: Text('What you asked for',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                  children: [
                    Text(asked, style: GoogleFonts.inter(fontSize: 13.5, height: 1.45, color: context.themeTextLight)),
                  ],
                ),
              )
            else
              const SizedBox(height: 14),

            // 3. Exactly what each choice means, so nothing feels like a trap
            _Reassure(icon: Icons.check_circle_rounded, color: AppTheme.success,
              text: 'Happy with it? Tap Looks good, and the order is done. The seller gets paid.'),
            _Reassure(icon: Icons.replay_circle_filled_rounded, color: Colors.orange,
              text: 'Not quite right? Asking for changes is free and keeps the order open.'),
            _Reassure(icon: Icons.forum_rounded, color: AppTheme.info,
              text: 'You can still message the seller after the order is done.'),
            if (autoDone != null)
              _Reassure(icon: Icons.schedule_rounded, color: context.themeTextLight,
                text: "No rush. If you don't answer, it completes by itself on ${_day(autoDone)}."),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onAskForChanges,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.themeTextDark,
                      side: BorderSide(color: context.themeBorder),
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    child: const Text('Ask for changes', maxLines: 1, softWrap: false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text('Looks good', maxLines: 1, softWrap: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Not now', style: GoogleFonts.inter(color: context.themeTextLight, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  static String _day(DateTime d) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }
}

class _Reassure extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Reassure({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: GoogleFonts.inter(fontSize: 13.5, height: 1.4, color: context.themeTextDark)),
          ),
        ],
      ),
    );
  }
}
