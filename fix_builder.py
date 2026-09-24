with open('lib/widgets/order_chat_cards.dart', 'r') as f:
    c = f.read()

old_builder = """class OrderChatCardBuilder extends StatelessWidget {
  final MessageModel message;
  final bool isCurrentUser;

  const OrderChatCardBuilder({
    super.key,
    required this.message,
    required this.isCurrentUser,
  });"""

new_builder = """class OrderChatCardBuilder extends StatelessWidget {
  final MessageModel message;
  final bool isCurrentUser;
  final bool isFreelancer;

  const OrderChatCardBuilder({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.isFreelancer = false,
  });"""

c = c.replace(old_builder, new_builder)
with open('lib/widgets/order_chat_cards.dart', 'w') as f:
    f.write(c)

with open('lib/screens/chat_screen.dart', 'r') as f:
    c2 = f.read()

old_call = """                                      ? OrderChatCardBuilder(
                                          message: msg,
                                          isCurrentUser: isMe,
                                        )"""

new_call = """                                      ? OrderChatCardBuilder(
                                          message: msg,
                                          isCurrentUser: isMe,
                                          isFreelancer: _isFreelancer,
                                        )"""
c2 = c2.replace(old_call, new_call)
with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(c2)
