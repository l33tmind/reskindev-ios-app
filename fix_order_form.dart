import 'dart:io';

void main() {
  final file = File('lib/screens/order_form_screen.dart');
  var content = file.readAsStringSync();
  
  final adminOld = '''
      for (var doc in adminSnap.docs) {
        final fcmToken = doc.data()['fcmToken'];
        if (fcmToken != null) {
          await NotificationService.sendPushNotification(
            fcmToken: fcmToken,
            title: 'New Order Received! 🚀',
            body: '\${FirebaseAuth.instance.currentUser?.displayName ?? "A client"} placed an order for \${gig.title}',
          );
        }
      }
''';

  final adminNew = '''
      for (var doc in adminSnap.docs) {
        await NotificationService.sendAndSaveNotification(
          userId: doc.id,
          title: 'New Order Received! 🚀',
          body: '\${FirebaseAuth.instance.currentUser?.displayName ?? "A client"} placed an order for \${gig.title}',
        );
      }
''';

  content = content.replaceAll(adminOld, adminNew);
  
  final clientOld = '''
      final clientFcm = clientDoc.data()?['fcmToken'];
      if (clientFcm != null) {
        await NotificationService.sendPushNotification(
          fcmToken: clientFcm,
          title: 'Order Placed Successfully! 🎉',
          body: 'Thank you for ordering \${gig.title}. We will review it and contact you shortly.',
        );
      }
''';

  final clientNew = '''
      await NotificationService.sendAndSaveNotification(
        userId: auth.user!.uid,
        title: 'Order Placed Successfully! 🎉',
        body: 'Thank you for ordering \${gig.title}. We will review it and contact you shortly.',
      );
''';

  content = content.replaceAll(clientOld, clientNew);
  file.writeAsStringSync(content);
  print('Updated order form to save notifications');
}
