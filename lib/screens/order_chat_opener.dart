import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../theme.dart';
import 'chat_screen.dart';

/// `/order-chat/:orderId`: opens the chat of an order, for the buyer or the seller.
/// Notifications link here, because an order's chat may not exist yet when the order is created;
/// the chat screen finds or creates it from the order.
class OrderChatOpener extends StatelessWidget {
  final String orderId;
  const OrderChatOpener({super.key, required this.orderId});

  Future<Map<String, String>?> _load() async {
    final doc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
    if (!doc.exists) return null;
    final order = OrderModel.fromFirestore(doc);
    final isSeller = FirebaseAuth.instance.currentUser?.uid == order.authorId;
    final otherId = isSeller ? order.clientUid : order.authorId;
    var name = isSeller ? order.userName : '';
    var avatar = '';
    try {
      final data = (await FirebaseFirestore.instance.collection('users').doc(otherId).get()).data();
      if (data != null) {
        if (name.isEmpty) name = data['name'] ?? data['displayName'] ?? data['username'] ?? '';
        avatar = data['photoUrl'] ?? data['profilePicture'] ?? '';
      }
    } catch (_) {}
    if (name.isEmpty) name = isSeller ? 'Buyer' : 'Seller';
    return {'otherId': otherId, 'name': name, 'avatar': avatar};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>?>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: context.themeBackground,
            body: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          );
        }
        final info = snap.data;
        if (info == null) {
          return Scaffold(
            backgroundColor: context.themeBackground,
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
            body: Center(child: Text('This order is no longer available.', style: TextStyle(color: context.themeTextLight))),
          );
        }
        return ChatScreen(
          chatId: 'new',
          targetUserId: info['otherId']!,
          targetUserName: info['name']!,
          targetUserAvatar: info['avatar']!,
          orderId: orderId,
        );
      },
    );
  }
}
