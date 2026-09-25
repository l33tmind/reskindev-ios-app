import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order_model.dart';
import 'workspace_details_sheet.dart';
import 'package:intl/intl.dart';
import '../models/chat_models.dart';
import '../theme.dart';

class OrderChatCardBuilder extends StatelessWidget {
  final MessageModel message;
  final bool isCurrentUser;
  final bool isFreelancer;

  const OrderChatCardBuilder({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.isFreelancer = false,
  });

  @override
  Widget build(BuildContext context) {
    final action = message.actionType ?? message.type;

    // We wrap all system cards in a Timeline Layout to match the web view
    return _TimelineWrapper(
      message: message,
      actionType: action,
      child: _buildCardContent(context, action),
    );
  }

  Widget _buildCardContent(BuildContext context, String action) {
    switch (action) {
      case 'payment_verified':
      case 'offer_accepted':
        return _PaymentVerifiedCard(message: message, isFreelancer: isFreelancer);
      case 'order_placed':
        return _OrderPlacedCard(message: message, isFreelancer: isFreelancer);
      case 'requirements_submitted':
      case 'requirements':
        return _RequirementsSubmittedCard(message: message, isFreelancer: isFreelancer);
      case 'order_delivered':
      case 'delivery':
        return _OrderDeliveredCard(message: message, isCurrentUser: isCurrentUser, isFreelancer: isFreelancer);
      case 'revision_requested':
        return _RevisionRequestedCard(message: message, isFreelancer: isFreelancer);
      case 'order_completed':
      case 'review':
        return _OrderCompletedCard(message: message, isFreelancer: isFreelancer);
      case 'custom_offer':
      case 'offer':
        return _CustomOfferCard(message: message, isCurrentUser: isCurrentUser);
      case 'order_started':
        return _OrderStartedCard(message: message);
      default:
        return _SimpleBannerCard(
          icon: Icons.info_outline_rounded,
          color: Colors.grey,
          title: 'System Notification',
          subtitle: message.text,
        );
    }
  }
}

// Wrapping layout with left timeline indicator
class _TimelineWrapper extends StatelessWidget {
  final MessageModel message;
  final String actionType;
  final Widget child;

  const _TimelineWrapper({
    required this.message,
    required this.actionType,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color iconColor;

    switch (actionType) {
      case 'order_placed':
        iconData = Icons.schedule_rounded;
        iconColor = Colors.amber;
        break;
      case 'payment_verified':
      case 'offer_accepted':
        iconData = Icons.account_balance_wallet_rounded;
        iconColor = Colors.green;
        break;
      case 'requirements_submitted':
      case 'requirements':
      case 'order_started':
        iconData = Icons.list_alt_rounded;
        iconColor = Colors.blue;
        break;
      case 'order_delivered':
      case 'delivery':
        iconData = Icons.inventory_2_rounded;
        iconColor = Colors.purple;
        break;
      case 'revision_requested':
        iconData = Icons.warning_amber_rounded;
        iconColor = Colors.orange;
        break;
      case 'order_completed':
      case 'review':
        iconData = Icons.check_circle_rounded;
        iconColor = const Color(0xFF10B981); // Emerald green like web
        break;
      case 'custom_offer':
      case 'offer':
        iconData = Icons.local_offer_rounded;
        iconColor = AppTheme.primary;
        break;
      default:
        iconData = Icons.info_rounded;
        iconColor = Colors.grey;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator column
          SizedBox(
            width: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Vertical Line
                Container(
                  width: 2,
                  color: context.themeBorder.withValues(alpha: 0.5),
                ),
                // Icon Bubble
                Positioned(
                  top: 24, // align with the top of the card roughly
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconData, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
          // Main Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _WebStyleCard extends StatelessWidget {
  final MessageModel message;
  final Widget child;
  final Widget? footer;

  const _WebStyleCard({
    required this.message,
    required this.child,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final String timeStr = message.createdAt != null
        ? DateFormat('HH:mm').format(message.createdAt!)
        : 'Now';

    final String orderId = message.orderId?.toUpperCase() ?? 'UNKNOWN';
    final String displayId = orderId.length > 6
        ? orderId.substring(0, 6)
        : orderId;

    return Container(
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Time and View Gig
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      timeStr,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.themeTextLight,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (message.orderId == null || message.orderId!.isEmpty) return;
                        
                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(child: CircularProgressIndicator()),
                        );
                        
                        try {
                          final doc = await FirebaseFirestore.instance.collection('orders').doc(message.orderId).get();
                          if (context.mounted) Navigator.pop(context); // pop loading
                          
                          if (doc.exists && context.mounted) {
                            final order = OrderModel.fromFirestore(doc);
                            // We need to know if current user is seller.
                            // The message model doesn't directly have this, but we can guess it or pass it.
                            // However, since we don't have isSeller easily available here without checking,
                            // we can check if the current user ID matches the order's authorId.
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            final isSeller = uid == order.authorId;
                            
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => WorkspaceDetailsSheet(
                                orderId: order.id!,
                                isSeller: isSeller,
                                chatId: 'unknown', // We don't have chatId easily here, but that's okay for display
                              ),
                            );
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order not found')));
                          }
                        } catch (e) {
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text('View Order'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        minimumSize: const Size(0, 28),
                        textStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Title
                Text(
                  'for order #$displayId',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.themeTextDark,
                  ),
                ),
                const SizedBox(height: 12),
                // Custom Content
                child,
              ],
            ),
          ),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}


class _OrderPlacedCard extends StatelessWidget {
  final MessageModel message;
  final bool isFreelancer;
  const _OrderPlacedCard({required this.message, this.isFreelancer = false});

  @override
  Widget build(BuildContext context) {
    return _WebStyleCard(
      message: message,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFreelancer ? 'New Order! ⏳' : 'Order Placed! ⏳',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.amber.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: Colors.amber.shade800,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isFreelancer ? 'Waiting for Admin Verification' : 'Pending Verification',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isFreelancer 
                      ? 'The buyer has placed a new order for "${message.gigTitle ?? 'your gig'}". The payment is currently pending verification by the Admin. Please wait for the payment to be secured before starting work.'
                      : 'Your order for "${message.gigTitle ?? 'the gig'}" has been created. Please wait while the Admin verifies your payment. Once verified, the funds will be secured in escrow.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: context.themeTextDark,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 1. Payment Verified

class _PaymentVerifiedCard extends StatelessWidget {
  final MessageModel message;
  final bool isFreelancer;
  const _PaymentVerifiedCard({required this.message, this.isFreelancer = false});

  @override
  Widget build(BuildContext context) {
    final price =
        message.price ??
        message.offerPrice ??
        (message.metadata?['price']) ??
        0.0;

    return _WebStyleCard(
      message: message,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Secured!',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF10B981),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment Verified by Admin',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'The escrow payment for "${message.gigTitle ?? 'your order'}" has been successfully verified.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: context.themeTextDark,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Buyer: Please submit your requirements.\nSeller: You may begin work once requirements are received.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.themeTextLight,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESCROW AMOUNT',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: context.themeTextLight,
                    ),
                  ),
                  Text(
                    '\$${price.toString()}',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.themeTextDark,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'HELD IN ESCROW',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      footer: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: Color(0xFF10B981),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "What's next: Buyer needs to submit requirements to start the order.",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: context.themeTextDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 2. Requirements Submitted
class _RequirementsSubmittedCard extends StatelessWidget {
  final MessageModel message;
  const _RequirementsSubmittedCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return _WebStyleCard(
      message: message,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Requirements Submitted',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
            ),
            child: Text(
              message.text.isNotEmpty
                  ? message.text
                  : 'The buyer has submitted the required information.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: context.themeTextDark,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
      footer: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.05),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.timer_outlined, size: 16, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "What's next: The countdown has started. Seller is working on it.",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: context.themeTextDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 3. Order Delivered
class _OrderDeliveredCard extends StatelessWidget {
  final MessageModel message;
  final bool isCurrentUser;
  final bool isFreelancer;

  const _OrderDeliveredCard({
    required this.message,
    required this.isCurrentUser,
    this.isFreelancer = false,
  });

  @override
  Widget build(BuildContext context) {
    final link = message.metadata?['deliveryLink'] ?? message.imageUrl ?? '';

    return _WebStyleCard(
      message: message,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFreelancer ? 'You Delivered the Final Work' : 'Seller Delivered the Final Work',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: GoogleFonts.inter(
                    color: context.themeTextDark,
                    height: 1.5,
                  ),
                ),
                if (link.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.themeSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: context.themeBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          color: Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'View Delivery File/Link',
                            style: GoogleFonts.inter(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      footer: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.05),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: Colors.purple,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isFreelancer 
                  ? "What's next: The buyer has 3 days to review your delivery and accept it."
                  : "What's next: You have 3 days to review the work and accept the delivery or request a revision.",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: context.themeTextDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 4. Revision Requested
class _RevisionRequestedCard extends StatelessWidget {
  final MessageModel message;
  final bool isFreelancer;
  const _RevisionRequestedCard({required this.message, this.isFreelancer = false});

  @override
  Widget build(BuildContext context) {
    return _WebStyleCard(
      message: message,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFreelancer ? 'Buyer Requested a Revision' : 'You Requested a Revision',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Text(
              message.text,
              style: GoogleFonts.inter(
                color: context.themeTextDark,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
      footer: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.05),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isFreelancer 
                  ? "What's next: Please review the buyer's notes and deliver the updated work."
                  : "What's next: The seller will review your notes and deliver the updated work.",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: context.themeTextDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 5. Order Completed (Success + Review) MATCHING WEB EXACTLY
class _OrderCompletedCard extends StatelessWidget {
  final MessageModel message;
  const _OrderCompletedCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final rating = message.rating ?? message.metadata?['rating'] ?? 0.0;
    final comment = message.comment ?? message.metadata?['comment'] ?? '';
    final price =
        message.price ??
        message.offerPrice ??
        message.metadata?['price'] ??
        0.0;
    // We will extract buyer initials or use 'BU' as fallback
    final senderInitials = message.senderName.isNotEmpty
        ? message.senderName.substring(0, 1).toUpperCase()
        : 'BU';

    return _WebStyleCard(
      message: message,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The buyer has accepted the delivery and payment has been transferred!',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF10B981),
              height: 1.4,
            ),
          ),
          if (rating > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.themeBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.themeBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: context.themeBorder,
                    child: Text(
                      senderInitials,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: context.themeTextLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Row(
                              children: List.generate(
                                5,
                                (index) => Icon(
                                  Icons.star_rounded,
                                  color: index < rating
                                      ? Colors.amber
                                      : Colors.grey.withValues(alpha: 0.3),
                                  size: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              rating.toStringAsFixed(1),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: context.themeTextDark,
                              ),
                            ),
                          ],
                        ),
                        if (comment.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '"$comment"',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: context.themeTextDark,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (price > 0) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FINAL AMOUNT PAID',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: context.themeTextLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${price.toString()}',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: context.themeTextDark,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'CLEARED',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      footer: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: Color(0xFF10B981),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "What's next: Transaction closed. Thank you for using Reskindev! If you need further revisions, please request a new custom offer.",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: context.themeTextDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Legacy Cards Below (Custom Offer, Order Started, Simple Banner)
class _CustomOfferCard extends StatelessWidget {
  final MessageModel message;
  final bool isCurrentUser;
  const _CustomOfferCard({required this.message, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    return _WebStyleCard(
      message: message,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_offer_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Custom Offer',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message.offerDescription ?? message.text,
            style: GoogleFonts.inter(color: context.themeTextDark),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PRICE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: context.themeTextLight,
                    ),
                  ),
                  Text(
                    '\$${message.offerPrice ?? 0}',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.themeTextDark,
                    ),
                  ),
                ],
              ),
              if (!isCurrentUser)
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please accept custom offers from the website version for now.')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  ),
                  child: Text(
                    'Accept Offer',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderStartedCard extends StatelessWidget {
  final MessageModel message;
  const _OrderStartedCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return _WebStyleCard(
      message: message,
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.rocket_launch_rounded,
              color: Colors.blue,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Order Started!',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.themeTextDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleBannerCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _SimpleBannerCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.themeTextDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
