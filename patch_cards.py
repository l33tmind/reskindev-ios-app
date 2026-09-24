with open('lib/widgets/order_chat_cards.dart', 'r') as f:
    c = f.read()

# Add to switch case
old_switch = """  switch (message.actionType) {
    case 'payment_verified':
      title = 'Payment Verified';"""

new_switch = """  switch (message.actionType) {
    case 'order_placed':
      title = 'Order Placed';
      timelineColor = const Color(0xFFF59E0B); // Amber
      icon = Icons.access_time_filled;
      break;
    case 'payment_verified':
      title = 'Payment Verified';"""

c = c.replace(old_switch, new_switch)

with open('lib/widgets/order_chat_cards.dart', 'w') as f:
    f.write(c)

with open('lib/widgets/chat_bubble.dart', 'r') as f:
    c2 = f.read()

c2 = c2.replace("['payment_verified', 'requirements_submitted', 'order_delivered', 'order_completed', 'revision_requested'].contains(message.actionType)",
                "['order_placed', 'payment_verified', 'requirements_submitted', 'order_delivered', 'order_completed', 'revision_requested'].contains(message.actionType)")
with open('lib/widgets/chat_bubble.dart', 'w') as f:
    f.write(c2)
