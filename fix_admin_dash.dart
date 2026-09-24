import 'dart:io';

void main() {
  final file = File('lib/screens/admin_dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  final oldUpdate = '''
        await FirebaseFirestore.instance
            .collection('users')
            .doc(order.clientUid)
            .collection('notifications')
            .add({
          'title': 'Order Updated',
          'body': 'Your order for \${order.gigTitle} is now \$newStatus',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await NotificationService.sendPushNotification(
          fcmToken: fcmToken,
          title: 'Order Updated',
          body: 'Your order for \${order.gigTitle} is now \$newStatus',
        );
''';

  final newUpdate = '''
        await NotificationService.sendAndSaveNotification(
          userId: order.clientUid,
          title: 'Order Updated',
          body: 'Your order for \${order.gigTitle} is now \$newStatus',
        );
''';

  content = content.replaceAll(oldUpdate, newUpdate);
  file.writeAsStringSync(content);
}
