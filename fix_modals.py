import re

with open('lib/widgets/workspace_timeline_modals.dart', 'r') as f:
    content = f.read()

# Replace sendSystemMessage calls
def replace_send(match):
    action = match.group(1)
    text = match.group(2)
    metadata = match.group(3) if match.lastindex >= 3 else ""
    
    res = f"""await Provider.of<ChatProvider>(context, listen: false).sendSystemMessage(
                orderId: order.id!,
                buyerId: order.userId,
                buyerName: order.userName,
                sellerId: order.authorId,
                sellerName: order.authorName,
                gigTitle: order.gigTitle,
                actionType: '{action}',
                text: {text},
              );"""
    
    if metadata and "metadata:" in metadata:
        # ChatProvider doesn't support metadata directly in sendSystemMessage, we need to update order status instead.
        pass
        
    return res

content = re.sub(r'await Provider\.of<ChatProvider>\(context, listen: false\)\.sendSystemMessage\(\s*orderId: order\.id!,\s*actionType: \'([^\']+)\',\s*text: ([^,]+),?\s*(metadata: [^,]+,?)?\s*\);', replace_send, content)

# Fix extraneous modifier
content = content.replace('  static void showSellerReview', '  static void showSellerReview')

with open('lib/widgets/workspace_timeline_modals.dart', 'w') as f:
    f.write(content)
