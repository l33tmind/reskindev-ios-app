import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/order_model.dart';

/// Opens the chat for an order, as buyer or seller. That chat is the one place to manage the order
/// (deliver, accept, ask for changes, review), so every "open this order" button leads here.
Future<void> openOrderChat(BuildContext context, OrderModel order) async {
  final me = FirebaseAuth.instance.currentUser?.uid;
  final isSeller = me == order.authorId;
  final otherId = isSeller ? order.clientUid : order.authorId;

  var name = isSeller ? order.userName : '';
  var avatar = '';
  if (name.isEmpty || name == 'Unknown') {
    try {
      final data = (await FirebaseFirestore.instance.collection('users').doc(otherId).get()).data();
      if (data != null) {
        name = data['name'] ?? data['displayName'] ?? data['username'] ?? '';
        avatar = data['photoUrl'] ?? data['profilePicture'] ?? '';
      }
    } catch (_) {}
  }
  if (name.isEmpty) name = isSeller ? 'Buyer' : 'Seller';
  if (!context.mounted) return;

  context.push('/chat/new', extra: {
    'targetUserId': otherId,
    'targetUserName': name,
    'targetUserAvatar': avatar,
    'orderId': order.id,
  });
}
