import 'dart:io';

void main() {
  final file = File('lib/screens/admin_dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  final oldLogic = '''
    if (order.id == null) return;
    await FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': newStatus});
    // Trigger push notification to client
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(order.clientUid).get();
      final fcmToken = userDoc.data()?['fcmToken'];
      if (fcmToken != null) {
        await NotificationService.sendAndSaveNotification(
          userId: order.clientUid,
          title: 'Order Updated',
          body: 'Your order for \${order.gigTitle} is now \$newStatus',
        );
      }
    } catch (e) {
      debugPrint('Error sending client notification: \$e');
    }
''';

  final newLogic = '''
    if (order.id == null) return;
    
    final oldStatus = order.status;
    await FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': newStatus});
    
    // Offline Escrow Logic: pending_payment -> requirements
    if (oldStatus == 'pending_payment' && newStatus == 'requirements') {
      try {
        // Notify Buyer
        await NotificationService.sendAndSaveNotification(
          userId: order.clientUid,
          title: 'Payment Secured! ✅',
          body: 'Reskindev has successfully held your escrow payment for \${order.gigTitle}. Please submit your requirements if you haven\\'t already.',
        );
        
        // Notify Seller (Freelancer)
        if (order.authorId.isNotEmpty) {
          await NotificationService.sendAndSaveNotification(
            userId: order.authorId,
            title: 'Escrow Payment Received! 🎉',
            body: 'Reskindev has secured the funds for \${order.gigTitle}. You can now safely start working on this order!',
          );
        }
      } catch (e) {
        debugPrint('Error sending escrow notifications: \$e');
      }
    } else {
      // Standard notification for other status updates
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(order.clientUid).get();
        final fcmToken = userDoc.data()?['fcmToken'];
        if (fcmToken != null) {
          await NotificationService.sendAndSaveNotification(
            userId: order.clientUid,
            title: 'Order Updated',
            body: 'Your order for \${order.gigTitle} is now \$newStatus',
          );
        }
      } catch (e) {
        debugPrint('Error sending client notification: \$e');
      }
    }
''';

  content = content.replaceAll(oldLogic, newLogic);
  file.writeAsStringSync(content);
}
