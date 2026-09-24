import re

with open('lib/screens/my_orders_screen.dart', 'r') as f:
    c = f.read()

old_call = """                        await chatProvider.sendSystemMessage(
                          buyerId: widget.order.clientUid,
                          buyerName: widget.order.clientName,
                          sellerId: widget.order.authorId,
                          sellerName: widget.order.userName,
                          orderId: widget.order.id ?? '',
                          gigTitle: widget.order.gigTitle,
                          actionType: 'order_completed',
                          text: 'Order Completed! Buyer left a ${overall.toStringAsFixed(1)}-star review.',
                        );"""

new_call = """                        await chatProvider.sendSystemMessage(
                          buyerId: widget.order.clientUid,
                          buyerName: widget.order.clientName,
                          sellerId: widget.order.authorId,
                          sellerName: widget.order.userName,
                          orderId: widget.order.id ?? '',
                          gigTitle: widget.order.gigTitle,
                          actionType: 'order_completed',
                          text: 'Order Completed! Buyer left a ${overall.toStringAsFixed(1)}-star review.',
                          metadata: {
                            'rating': overall,
                            'comment': publicCtrl.text.trim(),
                          },
                        );"""

c = c.replace(old_call, new_call)

with open('lib/screens/my_orders_screen.dart', 'w') as f:
    f.write(c)
