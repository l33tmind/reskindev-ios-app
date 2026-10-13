import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../providers/chat_provider.dart';

/// Admin changes an order's status from the app. Same rules and side effects as the website's
/// setOrderStatus server action (next-frontend/src/app/actions/admin.js), so an order looks and
/// behaves the same whichever place the admin used:
///  - one transaction: status + timestamps, and a refund to the buyer's wallet (once) on cancel;
///  - one chat card in the order's chat, which the server turns into the push + in-app notification
///    (requirements → "Payment secured", delivered → "Your delivery is ready", ...).
/// Only difference: the audit log (admin_logs) can only be written by the server, so the app skips it.
class AdminOrderStatus {
  /// Same card per status as the website, so the chat and the notifications match
  static const _cardFor = {
    'requirements': 'payment_verified',
    'processing': 'requirements_submitted',
    'in_progress': 'order_started',
    'delivered': 'order_delivered',
    'completed': 'order_completed',
    'revision': 'revision_requested',
    'disputed': 'dispute_opened',
  };

  /// Verifying an offline payment: pending_payment → requirements (the website's "Verify" button)
  static Future<double> verifyPayment(OrderModel order, ChatProvider chat) =>
      set(order, 'requirements', chat, reason: 'Payment verified by admin');

  /// Returns the refunded amount (0 when nothing was refunded). Throws a readable message on a blocked change.
  static Future<double> set(OrderModel order, String status, ChatProvider chat, {required String reason}) async {
    final id = order.id;
    if (id == null) throw 'Missing order.';
    final db = FirebaseFirestore.instance;
    final orderRef = db.collection('orders').doc(id);

    var refund = 0.0;
    var price = 0.0;
    var buyerId = '';
    var wasStatus = '';
    await db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw 'Order not found.';
      final d = snap.data()!;
      wasStatus = (d['status'] ?? '') as String;
      if (wasStatus == status) throw 'Order is already "$status".';
      if (wasStatus == 'cancelled') throw 'A cancelled order cannot be changed.';
      if (wasStatus == 'completed' && status != 'disputed') throw 'A completed order can only be moved to disputed.';

      final update = <String, dynamic>{'status': status, 'updatedAt': FieldValue.serverTimestamp()};
      // Work starts: the delivery countdown needs startedAt
      if (status == 'processing' || status == 'in_progress') {
        if (d['startedAt'] == null) update['startedAt'] = FieldValue.serverTimestamp();
        if (d['requirementsSubmittedAt'] == null) update['requirementsSubmittedAt'] = FieldValue.serverTimestamp();
      }
      if (status == 'completed' && d['completedAt'] == null) update['completedAt'] = FieldValue.serverTimestamp();

      price = ((d['price'] ?? 0) as num).toDouble();
      buyerId = (d['userId'] ?? d['clientUid'] ?? '') as String;
      if (status == 'cancelled') {
        update['cancelledAt'] = FieldValue.serverTimestamp();
        // Nothing was paid yet for an unverified offline order, so there is nothing to give back
        final wasPaid = wasStatus != 'pending_payment' && wasStatus != 'pending';
        final amount = (price * 100).round() / 100;
        if (wasPaid && buyerId.isNotEmpty && amount > 0 && d['isRefunded'] != true) {
          refund = amount;
          update['isRefunded'] = true;
          update['refundedAmount'] = amount;
          tx.update(db.collection('users').doc(buyerId), {'walletBalance': FieldValue.increment(amount)});
        }
      }
      tx.update(orderRef, update);
    });

    // Chat card (best effort, after the money part), same text as the website
    final title = order.gigTitle.isEmpty ? 'Order' : order.gigTitle;
    final label = status.replaceAll('_', ' ').toUpperCase();
    final text = status == 'requirements' && (wasStatus == 'pending_payment' || wasStatus == 'pending')
        ? 'Payment verified. Reskindev is holding the funds safely until the order is complete.'
        : status == 'cancelled'
            ? 'Order "$title" was cancelled by Reskindev Admin.'
                '${refund > 0 ? ' \$${refund.toStringAsFixed(2)} was refunded to the buyer\'s wallet.' : ''}\nReason: $reason'
            : 'Order "$title" status changed to $label by Reskindev Admin.\nReason: $reason';
    await chat.sendSystemMessage(
      orderId: id,
      buyerId: buyerId.isEmpty ? order.userId : buyerId,
      buyerName: order.userName,
      sellerId: order.authorId,
      sellerName: 'Seller',
      gigTitle: order.gigTitle,
      actionType: _cardFor[status] ?? 'system_update',
      text: text,
      price: price,
    );
    return refund;
  }
}
