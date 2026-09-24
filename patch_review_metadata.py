import re

with open('lib/widgets/workspace_timeline_modals.dart', 'r') as f:
    c = f.read()

old_call = """                  await Provider.of<ChatProvider>(context, listen: false).sendSystemMessage(
                    orderId: order.id!,
                    buyerId: order.userId,
                    buyerName: order.userName,
                    sellerId: order.authorId,
                    sellerName: 'Seller',
                    gigTitle: order.gigTitle,
                    actionType: 'order_completed',
                    text: 'The buyer has accepted the delivery and payment has been transferred!',
                  );"""

new_call = """                  await Provider.of<ChatProvider>(context, listen: false).sendSystemMessage(
                    orderId: order.id!,
                    buyerId: order.userId,
                    buyerName: order.userName,
                    sellerId: order.authorId,
                    sellerName: 'Seller',
                    gigTitle: order.gigTitle,
                    actionType: 'order_completed',
                    text: 'The buyer has accepted the delivery and payment has been transferred!',
                    metadata: {
                      'rating': calculatedRating,
                      'comment': ctrl.text.trim(),
                    },
                  );"""

c = c.replace(old_call, new_call)

with open('lib/widgets/workspace_timeline_modals.dart', 'w') as f:
    f.write(c)
