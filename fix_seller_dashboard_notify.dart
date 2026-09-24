import 'dart:io';

void main() {
  final file = File('lib/screens/seller_dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  // Add import if missing
  if (!content.contains('notification_service.dart')) {
    content = content.replaceFirst(
      "import '../providers/auth_provider.dart';", 
      "import '../providers/auth_provider.dart';\nimport '../services/notification_service.dart';"
    );
  }

  // 1. Start Work Notification
  final oldStartWork = '''
      return _buildButton(context, AppTheme.primary, 'Start Work', () {
        FirebaseFirestore.instance.collection('orders').doc(order.id).update({
          'status': 'in_progress',
          'startedAt': FieldValue.serverTimestamp(),
        });
      });
''';
  final newStartWork = '''
      return _buildButton(context, AppTheme.primary, 'Start Work', () async {
        await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
          'status': 'in_progress',
          'startedAt': FieldValue.serverTimestamp(),
        });
        await NotificationService.sendAndSaveNotification(
          userId: order.clientUid,
          title: 'Order Started',
          body: 'The seller has started working on your order: \${order.gigTitle}',
        );
      });
''';
  if (content.contains(oldStartWork)) {
    content = content.replaceFirst(oldStartWork, newStartWork);
  }

  // 2. Deliver Work Notification
  final oldDeliver = '''
              Navigator.pop(c);
              await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                'status': 'delivered',
                'deliveryLink': linkCtrl.text.trim(),
                'deliveryNote': noteCtrl.text.trim(),
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work Delivered Successfully!')));
''';
  final newDeliver = '''
              Navigator.pop(c);
              await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                'status': 'delivered',
                'deliveryLink': linkCtrl.text.trim(),
                'deliveryNote': noteCtrl.text.trim(),
              });
              await NotificationService.sendAndSaveNotification(
                userId: order.clientUid,
                title: 'Order Delivered',
                body: 'The seller has delivered the work for: \${order.gigTitle}. Please review it.',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work Delivered Successfully!')));
              }
''';
  if (content.contains(oldDeliver)) {
    content = content.replaceFirst(oldDeliver, newDeliver);
  }

  file.writeAsStringSync(content);
  print('Added notifications to seller_dashboard_screen.dart');
}
