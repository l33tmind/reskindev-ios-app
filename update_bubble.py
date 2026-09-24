with open('lib/widgets/chat_bubble.dart', 'r') as f:
    c = f.read()

c = c.replace("final bool isRead;", "final bool isRead;\n  final bool isFreelancer;")
c = c.replace("required this.isMe,", "required this.isMe,\n    this.isFreelancer = false,")
c = c.replace("return buildSystemMessageCard(context, message);", "return buildSystemMessageCard(context, message, isFreelancer: isFreelancer);")
with open('lib/widgets/chat_bubble.dart', 'w') as f:
    f.write(c)

with open('lib/screens/chat_screen.dart', 'r') as f:
    c2 = f.read()
c2 = c2.replace("ChatBubble(", "ChatBubble(\n                                          isFreelancer: _isFreelancer,")
with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(c2)

with open('lib/widgets/order_chat_cards.dart', 'r') as f:
    c3 = f.read()

c3 = c3.replace("Widget buildSystemMessageCard(BuildContext context, MessageModel message) {", "Widget buildSystemMessageCard(BuildContext context, MessageModel message, {bool isFreelancer = false}) {")
c3 = c3.replace("return _PaymentVerifiedCard(message: message);", "return _PaymentVerifiedCard(message: message, isFreelancer: isFreelancer);")

old_payment_card = """class _PaymentVerifiedCard extends StatelessWidget {
  final MessageModel message;
  const _PaymentVerifiedCard({required this.message});"""

new_payment_card = """class _PaymentVerifiedCard extends StatelessWidget {
  final MessageModel message;
  final bool isFreelancer;
  const _PaymentVerifiedCard({required this.message, this.isFreelancer = false});"""
c3 = c3.replace(old_payment_card, new_payment_card)
with open('lib/widgets/order_chat_cards.dart', 'w') as f:
    f.write(c3)

