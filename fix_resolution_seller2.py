import re

with open('lib/screens/seller_dashboard_screen.dart', 'r') as f:
    content = f.read()

old_action2 = """    } else if (order.status == 'in_progress' || order.status == 'revision') {
      return _buildButton(context, const Color(0xFF8B5CF6), 'Deliver Work', () {
        _showDeliveryModal(context, order);
      });
    } else if (order.status == 'delivered') {"""

new_action2 = """    } else if (order.status == 'in_progress' || order.status == 'revision') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildButton(context, const Color(0xFF8B5CF6), 'Deliver Work', () {
            _showDeliveryModal(context, order);
          }),
          const SizedBox(height: 8),
          _buildButton(context, const Color(0xFFDC2626), 'Request Cancellation', () {
            FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': 'cancel_requested_by_freelancer'});
          }),
        ],
      );
    } else if (order.status == 'delivered') {"""
content = content.replace(old_action2, new_action2)

with open('lib/screens/seller_dashboard_screen.dart', 'w') as f:
    f.write(content)

print("Updated Resolution Center for Seller Cancel Request")
