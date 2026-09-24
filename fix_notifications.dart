import 'dart:io';

void main() {
  final file = File('lib/services/notification_service.dart');
  var content = file.readAsStringSync();
  
  if (!content.contains('import \'package:cloud_firestore/cloud_firestore.dart\';')) {
    content = content.replaceFirst(
      'import \'package:googleapis_auth/auth_io.dart\';',
      'import \'package:googleapis_auth/auth_io.dart\';\nimport \'package:cloud_firestore/cloud_firestore.dart\';'
    );
  }

  if (!content.contains('Future<void> sendAndSaveNotification')) {
    final newMethod = '''
  static Future<void> sendAndSaveNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    try {
      // 1. Save to in-app notifications
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Fetch FCM token and send push
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        final fcmToken = doc.data()?['fcmToken'] as String?;
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await sendPushNotification(fcmToken: fcmToken, title: title, body: body);
        }
      }
    } catch (e) {
      debugPrint('Error saving/sending notification: \$e');
    }
  }
}''';
    
    // Replace the last closing brace with the new method
    content = content.substring(0, content.lastIndexOf('}')) + newMethod;
    file.writeAsStringSync(content);
    print('Added sendAndSaveNotification to NotificationService');
  } else {
    print('Already has sendAndSaveNotification');
  }
}
