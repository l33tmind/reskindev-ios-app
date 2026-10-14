import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/chat_models.dart';
import '../theme.dart';
import 'custom_offer.dart';

/// Order events in the chat (order placed, paid, delivered, ...).
///
/// These are a short history only: one small card per event, no buttons.
/// Everything the buyer or seller can do lives in one place, the panel at the top of the chat
/// (OrderNextStepPanel), so nobody has to wonder which of three "Accept" buttons to press.
class OrderChatCardBuilder extends StatelessWidget {
  final MessageModel message;
  final bool isCurrentUser;
  final bool isFreelancer;
  final String chatId;

  const OrderChatCardBuilder({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.isFreelancer = false,
    this.chatId = '',
  });

  static const _purple = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    final action = message.actionType ?? message.type;
    final note = message.text.trim();

    switch (action) {
      case 'order_placed':
        return _EventCard(
          message: message,
          icon: Icons.shopping_bag_outlined,
          color: Colors.amber.shade700,
          title: 'Order placed',
          subtitle: isFreelancer ? 'Waiting for the buyer\'s payment to be confirmed.' : 'We\'re confirming your payment.',
          showPrice: true,
        );
      case 'payment_verified':
      case 'offer_accepted':
        return _EventCard(
          message: message,
          icon: Icons.verified_user_rounded,
          color: AppTheme.success,
          title: 'Payment secured',
          subtitle: 'Held safely by Reskindev until the order is complete.',
          showPrice: true,
        );
      case 'requirements_submitted':
      case 'requirements':
        return _EventCard(
          message: message,
          icon: Icons.assignment_outlined,
          color: AppTheme.info,
          title: isFreelancer ? 'The buyer shared requirements' : 'You shared requirements',
          note: note.replaceFirst('The buyer has submitted the requirements.', '').trim(),
        );
      case 'custom_offer_accepted':
        return _EventCard(
          message: message,
          icon: Icons.handshake_rounded,
          color: AppTheme.success,
          title: 'Custom offer accepted',
          subtitle: isFreelancer ? 'Your turn: start the work and deliver it here.' : 'The seller can start right away.',
          showPrice: true,
        );
      case 'order_started':
        return _EventCard(
          message: message,
          icon: Icons.rocket_launch_rounded,
          color: AppTheme.info,
          title: 'Work started',
        );
      case 'order_delivered':
      case 'delivery':
        return _EventCard(
          message: message,
          icon: Icons.inventory_2_rounded,
          color: _purple,
          title: isFreelancer ? 'You delivered' : 'Delivery received',
          note: note,
        );
      case 'revision_requested':
        return _EventCard(
          message: message,
          icon: Icons.edit_note_rounded,
          color: Colors.orange,
          title: isFreelancer ? 'The buyer asked for changes' : 'You asked for changes',
          note: note,
        );
      case 'order_completed':
      case 'review':
        return _EventCard(
          message: message,
          icon: Icons.celebration_rounded,
          color: AppTheme.success,
          title: 'Order completed',
          subtitle: isFreelancer ? 'Payment is released to you.' : 'Thanks! The payment is released to the seller.',
        );
      case 'reviews_published':
        final meta = message.metadata ?? {};
        final buyerRating = (meta['buyerRating'] as num?)?.toDouble() ?? 0;
        final sellerRating = (meta['sellerRating'] as num?)?.toDouble() ?? 0;
        return _EventCard(
          message: message,
          icon: Icons.star_rounded,
          color: Colors.amber.shade700,
          title: 'Reviews published',
          subtitle: [
            if (buyerRating > 0) 'Buyer: ${buyerRating.toStringAsFixed(1)}★',
            if (sellerRating > 0) 'Seller: ${sellerRating.toStringAsFixed(1)}★',
          ].join('  ·  '),
          note: (meta['buyerComment'] ?? '').toString(),
        );
      case 'custom_offer':
      case 'offer':
        return CustomOfferCard(message: message, isMine: isCurrentUser, chatId: chatId);
      default:
        return _EventCard(
          message: message,
          icon: Icons.info_outline_rounded,
          color: Colors.grey,
          title: note.isEmpty ? 'Update' : note,
        );
    }
  }
}

String _money(num value) => '\$${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}';

/// One order event: colored icon, short title, time, and an optional note the person wrote.
class _EventCard extends StatelessWidget {
  final MessageModel message;
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? note;
  final bool showPrice;

  const _EventCard({
    required this.message,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.note,
    this.showPrice = false,
  });

  @override
  Widget build(BuildContext context) {
    final time = message.createdAt != null ? DateFormat('h:mm a').format(message.createdAt!) : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDarkMode ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                    ),
                    if (showPrice) _Price(message: message),
                    if (time.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(time, style: GoogleFonts.inter(fontSize: 11, color: context.themeTextLight)),
                    ],
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: GoogleFonts.inter(fontSize: 12.5, height: 1.35, color: context.themeTextLight)),
                ],
                if (note != null && note!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SelectableText(note!,
                    style: GoogleFonts.inter(fontSize: 13.5, height: 1.4, color: context.themeTextDark)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The amount on "Order placed" / "Payment secured". Older messages carry no price, so it falls back to the order.
class _Price extends StatelessWidget {
  final MessageModel message;
  const _Price({required this.message});

  Widget _text(BuildContext context, num value) => value <= 0
      ? const SizedBox.shrink()
      : Text(_money(value),
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: context.themeTextDark));

  @override
  Widget build(BuildContext context) {
    final num price = message.price ?? message.offerPrice ?? (message.metadata?['price'] as num?) ?? 0;
    final orderId = message.orderId ?? '';
    if (price > 0 || orderId.isEmpty) return _text(context, price);
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('orders').doc(orderId).get(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        return _text(context, (data?['price'] as num?) ?? 0);
      },
    );
  }
}
