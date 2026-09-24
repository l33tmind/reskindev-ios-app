import re

with open('lib/screens/seller_dashboard_screen.dart', 'r') as f:
    content = f.read()

# Add chat_provider import
if 'import \'../providers/chat_provider.dart\' as chat;' not in content:
    content = content.replace("import '../providers/auth_provider.dart' as ap;", "import '../providers/auth_provider.dart' as ap;\nimport '../providers/chat_provider.dart' as chat;")

# 1. Update 'Start Work' (requirements -> in_progress)
old_start = """    } else if (order.status == 'requirements') {
      return _buildButton(context, AppTheme.primary, 'Start Work', () async {
        await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
          'status': 'in_progress',
          'startedAt': FieldValue.serverTimestamp(),
        });
        await NotificationService.sendAndSaveNotification(
          userId: order.clientUid,
          title: 'Order Started',
          body: 'The seller has started working on your order: ${order.gigTitle}',
        );
      });"""

new_start = """    } else if (order.status == 'requirements') {
      return _buildButton(context, AppTheme.primary, 'Start Work', () async {
        await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
          'status': 'in_progress',
          'startedAt': FieldValue.serverTimestamp(),
        });
        
        try {
          if (context.mounted) {
            final chatProvider = context.read<chat.ChatProvider>();
            await chatProvider.sendSystemMessage(
              buyerId: order.clientUid,
              buyerName: order.clientName,
              sellerId: order.authorId,
              sellerName: order.userName,
              orderId: order.id,
              gigTitle: order.gigTitle,
              actionType: 'requirements_submitted',
              text: 'Requirements Submitted. The seller has started working.',
            );
          }
        } catch (e) {
          print('System msg err: $e');
        }

        await NotificationService.sendAndSaveNotification(
          userId: order.clientUid,
          title: 'Order Started',
          body: 'The seller has started working on your order: ${order.gigTitle}',
        );
      });"""
content = content.replace(old_start, new_start)

# 2. Update Submit Delivery
old_delivery = """              await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                'status': 'delivered',
                'deliveryNote': noteCtrl.text.trim(),
                'deliveredAt': FieldValue.serverTimestamp(),
              });
              
              // Automatically send delivery message to Inbox
              try {
                final myId = FirebaseAuth.instance.currentUser?.uid;
                if (myId != null) {
                  final chatId = myId.compareTo(order.clientUid) < 0 ? '${myId}_${order.clientUid}' : '${order.clientUid}_$myId';
                  final chatRef = FirebaseFirestore.instance.collection('conversations').doc(chatId);
                  
                  final message = {
                    'senderId': myId,
                    'text': '🎉 I have delivered your order for "${order.gigTitle}". Please review it from the Orders page!\\n\\nDelivery Note:\\n${noteCtrl.text.trim()}',
                    'createdAt': FieldValue.serverTimestamp(),
                    'type': 'text',
                    'senderName': order.userName,
                  };"""

new_delivery = """              await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                'status': 'delivered',
                'deliveryNote': noteCtrl.text.trim(),
                'deliveredAt': FieldValue.serverTimestamp(),
              });
              
              // Automatically send delivery message to Inbox
              try {
                if (context.mounted) {
                  final chatProvider = context.read<chat.ChatProvider>();
                  await chatProvider.sendSystemMessage(
                    buyerId: order.clientUid,
                    buyerName: order.clientName,
                    sellerId: order.authorId,
                    sellerName: order.userName,
                    orderId: order.id,
                    gigTitle: order.gigTitle,
                    actionType: 'order_delivered',
                    text: 'Order Delivered! Please review the delivery.\\n\\nNote: ${noteCtrl.text.trim()}',
                  );
                }

                final myId = FirebaseAuth.instance.currentUser?.uid;
                if (myId != null) {
                  final chatId = myId.compareTo(order.clientUid) < 0 ? '${myId}_${order.clientUid}' : '${order.clientUid}_$myId';
                  final chatRef = FirebaseFirestore.instance.collection('conversations').doc(chatId);
                  
                  final message = {
                    'senderId': myId,
                    'text': '🎉 I have delivered your order for "${order.gigTitle}". Please review it from the Orders page!\\n\\nDelivery Note:\\n${noteCtrl.text.trim()}',
                    'createdAt': FieldValue.serverTimestamp(),
                    'type': 'text',
                    'senderName': order.userName,
                  };"""
content = content.replace(old_delivery, new_delivery)

with open('lib/screens/seller_dashboard_screen.dart', 'w') as f:
    f.write(content)

print("Updated SellerDashboardScreen with system messages")
