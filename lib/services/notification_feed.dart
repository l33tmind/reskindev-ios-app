import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// One notification, whichever collection it was saved in.
///  - notifications/{id}                  (server order events, website admin; fields: message, read)
///  - users/{uid}/notifications/{id}      (older app notifications; fields: body, isRead)
class AppNotif {
  final DocumentReference ref;
  final bool legacy;
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;
  final String type;
  final String route;
  final String orderNumber;
  final String invoiceNumber;

  AppNotif._({
    required this.ref,
    required this.legacy,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    required this.type,
    required this.route,
    required this.orderNumber,
    required this.invoiceNumber,
  });

  factory AppNotif.fromDoc(QueryDocumentSnapshot doc, {required bool legacy}) {
    final d = doc.data() as Map<String, dynamic>;
    var route = (d['route'] ?? '').toString();
    final link = (d['link'] ?? '').toString();
    if (route.isEmpty && link.contains('orders')) route = '/my-orders';
    // An order notification always opens that order's chat, where the person acts on it.
    // Older ones pointed at My Orders or the Seller Dashboard.
    final orderId = (d['orderId'] ?? '').toString();
    if (orderId.isNotEmpty && (route.isEmpty || route == '/my-orders' || route == '/seller')) {
      route = '/order-chat/$orderId';
    }
    var title = (d['title'] ?? 'Notification').toString();
    var body = (legacy ? d['body'] : d['message'] ?? d['body'] ?? '')?.toString() ?? '';
    // Old admin messages are all titled "Order Update" with the real headline inside the text,
    // e.g. "🎉 Escrow Payment Received! Reskindev has secured...". Pull the headline out as the title.
    if (title == 'Order Update') {
      final clean = body.replaceFirst(RegExp(r'^[^A-Za-z0-9"]+'), '').trim();
      final bang = clean.indexOf('!');
      if (bang > 0 && bang < 50) {
        title = clean.substring(0, bang + 1);
        body = clean.substring(bang + 1).trim();
      }
    }
    return AppNotif._(
      ref: doc.reference,
      legacy: legacy,
      title: title,
      body: body,
      read: legacy ? d['isRead'] == true : d['read'] == true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      type: (d['type'] ?? '').toString(),
      route: route,
      orderNumber: (d['orderNumber'] ?? '').toString(),
      invoiceNumber: (d['invoiceNumber'] ?? '').toString(),
    );
  }

  Future<void> markRead() => ref.update({legacy ? 'isRead' : 'read': true});

  /// Opening a chat answers its notifications: mark every unread one for that chat (or its order) as read,
  /// so the bell only counts things the person hasn't seen yet.
  static Future<void> markChatRead(String uid, {required String chatId, String? orderId}) async {
    final col = FirebaseFirestore.instance.collection('notifications');
    try {
      final byChat = await col.where('userId', isEqualTo: uid).where('chatId', isEqualTo: chatId).get();
      final byOrder = (orderId == null || orderId.isEmpty)
          ? null
          : await col.where('userId', isEqualTo: uid).where('orderId', isEqualTo: orderId).get();
      final unread = {
        for (final d in [...byChat.docs, ...?byOrder?.docs])
          if (d.data()['read'] != true) d.id: d.reference,
      };
      if (unread.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final ref in unread.values) {
        batch.update(ref, {'read': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Newest first, both collections merged.
  static Stream<List<AppNotif>> stream(String uid) {
    final db = FirebaseFirestore.instance;
    final controller = StreamController<List<AppNotif>>();
    var top = <AppNotif>[];
    var legacy = <AppNotif>[];

    void emit() {
      final all = [...top, ...legacy]
        ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
      if (!controller.isClosed) controller.add(all.take(100).toList());
    }

    final subs = <StreamSubscription>[
      db.collection('notifications').where('userId', isEqualTo: uid).snapshots().listen((s) {
        top = s.docs.map((d) => AppNotif.fromDoc(d, legacy: false)).toList();
        emit();
      }, onError: (_) {}),
      db.collection('users').doc(uid).collection('notifications').snapshots().listen((s) {
        legacy = s.docs.map((d) => AppNotif.fromDoc(d, legacy: true)).toList();
        emit();
      }, onError: (_) {}),
    ];
    controller.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
    };
    return controller.stream;
  }
}
