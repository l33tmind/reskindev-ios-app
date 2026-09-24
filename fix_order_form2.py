import re

with open('lib/screens/order_form_screen.dart', 'r') as f:
    content = f.read()

old_code = """      if (context.mounted) {
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
      }"""

new_code = """      if (context.mounted) {
        final chatProvider = context.read<chat.ChatProvider>();
        await chatProvider.sendSystemMessage(
          buyerId: order.clientUid,
          buyerName: order.clientName,
          sellerId: order.authorId,
          sellerName: gig.authorName,
          orderId: docRef.id,
          gigTitle: order.gigTitle,
          actionType: 'order_placed',
          text: 'Order Placed: \$${order.price.toStringAsFixed(0)} for ${order.gigTitle}',
        );
      }"""

content = content.replace(old_code, new_code)
content = content.replace("import '../providers/chat_provider.dart' as ap;", "import '../providers/chat_provider.dart' as chat;")

with open('lib/screens/order_form_screen.dart', 'w') as f:
    f.write(content)

print("Fixed OrderFormScreen syntax")
