import re

with open('lib/screens/order_form_screen.dart', 'r') as f:
    content = f.read()

old_add = """    await FirebaseFirestore.instance.collection('orders').add(orderMap);"""

new_add = """    final docRef = await FirebaseFirestore.instance.collection('orders').add(orderMap);
    
    // Trigger system message
    try {
      if (context.mounted) {
        final chatProvider = context.read<ap.ChatProvider>();
        await chatProvider.sendSystemMessage(
          buyerId: order.clientUid,
          buyerName: order.clientName,
          sellerId: order.authorId,
          sellerName: widget.gig.authorName,
          orderId: docRef.id,
          gigTitle: order.gigTitle,
          actionType: 'order_placed',
          text: 'Order Placed: \$${order.price.toStringAsFixed(0)} for ${order.gigTitle}',
        );
      }
    } catch (e) {
      print('System message error: $e');
    }"""
content = content.replace(old_add, new_add)

# Add import if missing
if 'import \'../providers/chat_provider.dart\' as ap;' not in content:
    content = content.replace("import '../providers/auth_provider.dart';", "import '../providers/auth_provider.dart';\nimport '../providers/chat_provider.dart' as ap;")

with open('lib/screens/order_form_screen.dart', 'w') as f:
    f.write(content)

print("Updated Order Form")
