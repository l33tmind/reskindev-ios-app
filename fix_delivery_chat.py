import re

with open('lib/screens/seller_dashboard_screen.dart', 'r') as f:
    content = f.read()

old_deliver = """              await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                'status': 'delivered',
                'deliveryNote': noteCtrl.text.trim(),
                'deliveredAt': FieldValue.serverTimestamp(),
              });
              // Send notification to buyer
              try {"""

new_deliver = """              await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
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
                    'text': '🎉 I have delivered your order for \\"${order.gigTitle}\\". Please review it from the Orders page!\\n\\nDelivery Note:\\n${noteCtrl.text.trim()}',
                    'createdAt': FieldValue.serverTimestamp(),
                  };
                  
                  await chatRef.collection('messages').add(message);
                  await chatRef.set({
                    'participants': [myId, order.clientUid],
                    'lastMessage': 'Order Delivered',
                    'lastMessageTime': FieldValue.serverTimestamp(),
                    'unreadCount': {order.clientUid: FieldValue.increment(1)}
                  }, SetOptions(merge: true));
                }
              } catch (e) {
                print('Error sending delivery message: $e');
              }
              
              // Send notification to buyer
              try {"""
content = content.replace(old_deliver, new_deliver)

with open('lib/screens/seller_dashboard_screen.dart', 'w') as f:
    f.write(content)

print("Added Automated Delivery Inbox Message")
