import re

with open('lib/screens/my_orders_screen.dart', 'r') as f:
    content = f.read()

# Add chat_provider import
if 'import \'../providers/chat_provider.dart\' as chat;' not in content:
    content = content.replace("import '../providers/auth_provider.dart' as ap;", "import '../providers/auth_provider.dart' as ap;\nimport '../providers/chat_provider.dart' as chat;")

old_review = """                    // 1. Update Order
                    await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({
                      'status': 'completed',
                      'hasReview': true,
                      'completedAt': FieldValue.serverTimestamp(),
                      'ratingCommunication': comms,
                      'ratingQuality': quality,
                      'ratingDescribed': described,
                      'overallRating': overall,
                      'publicReview': publicCtrl.text.trim(),
                      'privateFeedback': privateCtrl.text.trim(),
                    });"""

new_review = """                    // 1. Update Order
                    await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({
                      'status': 'completed',
                      'hasReview': true,
                      'completedAt': FieldValue.serverTimestamp(),
                      'ratingCommunication': comms,
                      'ratingQuality': quality,
                      'ratingDescribed': described,
                      'overallRating': overall,
                      'publicReview': publicCtrl.text.trim(),
                      'privateFeedback': privateCtrl.text.trim(),
                    });
                    
                    // Trigger system message
                    try {
                      if (context.mounted) {
                        final chatProvider = context.read<chat.ChatProvider>();
                        await chatProvider.sendSystemMessage(
                          buyerId: widget.order.clientUid,
                          buyerName: widget.order.clientName,
                          sellerId: widget.order.authorId,
                          sellerName: widget.order.userName,
                          orderId: widget.order.id,
                          gigTitle: widget.order.gigTitle,
                          actionType: 'order_completed',
                          text: 'Order Completed! Buyer left a 5-star review.',
                        );
                      }
                    } catch (e) {
                      print('System msg err: $e');
                    }"""

content = content.replace(old_review, new_review)

with open('lib/screens/my_orders_screen.dart', 'w') as f:
    f.write(content)

print("Updated my_orders_screen.dart with order_completed system message")
