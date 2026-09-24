import 'dart:io';

void main() {
  final file = File('lib/screens/my_orders_screen.dart');
  var content = file.readAsStringSync();
  
  if (!content.contains('notification_service.dart')) {
    content = content.replaceFirst(
      "import '../theme.dart';", 
      "import '../theme.dart';\nimport '../services/notification_service.dart';"
    );
  }

  // 1. Approve & Accept Delivery is handled inside `RatingDialog` (which is in `my_orders_screen.dart` or maybe a separate file?)
  // Let's check if RatingDialog is in my_orders_screen.dart
  // Yes, I saw it earlier.

  final oldSubmitReview = '''
                  await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({
                    'status': 'completed',
                    'completedAt': FieldValue.serverTimestamp(),
                    'ratingCommunication': _rating1,
                    'ratingQuality': _rating2,
                    'ratingDescribed': _rating3,
                    'overallRating': overall,
                    'publicReview': _publicCtrl.text,
                    'privateFeedback': _privateCtrl.text,
                  });
''';
  final newSubmitReview = '''
                  await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({
                    'status': 'completed',
                    'completedAt': FieldValue.serverTimestamp(),
                    'ratingCommunication': _rating1,
                    'ratingQuality': _rating2,
                    'ratingDescribed': _rating3,
                    'overallRating': overall,
                    'publicReview': _publicCtrl.text,
                    'privateFeedback': _privateCtrl.text,
                  });
                  await NotificationService.sendAndSaveNotification(
                    userId: widget.order.authorId,
                    title: 'Order Completed',
                    body: 'The buyer has accepted the delivery and left a \${overall.toStringAsFixed(1)}-star review!',
                  );
''';
  if (content.contains(oldSubmitReview)) {
    content = content.replaceFirst(oldSubmitReview, newSubmitReview);
  }

  // 2. Request Revision
  final oldRevision = '''
              Navigator.pop(c);
              await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                'status': 'revision',
                'revisionNote': noteCtrl.text.trim(),
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revision Requested!')));
''';
  final newRevision = '''
              Navigator.pop(c);
              await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                'status': 'revision',
                'revisionNote': noteCtrl.text.trim(),
              });
              await NotificationService.sendAndSaveNotification(
                userId: order.authorId,
                title: 'Revision Requested',
                body: 'The buyer requested a revision for: \${order.gigTitle}',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revision Requested!')));
              }
''';
  if (content.contains(oldRevision)) {
    content = content.replaceFirst(oldRevision, newRevision);
  }

  file.writeAsStringSync(content);
  print('Added notifications to my_orders_screen.dart');
}
