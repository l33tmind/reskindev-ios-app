import re

with open('lib/screens/seller_dashboard_screen.dart', 'r') as f:
    content = f.read()

old_action = """    } else if (order.status == 'cancelled') {
      return _buildLabel(const Color(0xFFDC2626), const Color(0xFFFEF2F2), const Color(0xFFFECACA), 'Order Cancelled');
    }

    return const SizedBox();"""

new_action = """    } else if (order.status == 'cancelled') {
      return _buildLabel(const Color(0xFFDC2626), const Color(0xFFFEF2F2), const Color(0xFFFECACA), 'Order Cancelled');
    } else if (order.status == 'cancel_requested_by_freelancer') {
      return _buildLabel(const Color(0xFFF97316), const Color(0xFFFFF7ED), const Color(0xFFFFEDD5), 'Cancellation Pending Buyer Approval');
    } else if (order.status == 'cancel_requested_by_buyer') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildButton(context, const Color(0xFFDC2626), 'Accept Cancellation', () {
            FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': 'cancelled'});
          }),
          const SizedBox(height: 8),
          _buildButton(context, const Color(0xFF3B82F6), 'Decline', () {
            FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': 'in_progress'});
          }),
          const SizedBox(height: 8),
          _buildButton(context, const Color(0xFF9CA3AF), 'Involve Admin', () {
            FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': 'disputed'});
          }),
        ],
      );
    } else if (order.status == 'disputed') {
      return _buildLabel(const Color(0xFFDC2626), const Color(0xFFFEF2F2), const Color(0xFFFECACA), 'Order Disputed (Admin Review)');
    }

    return const SizedBox();"""
content = content.replace(old_action, new_action)

# Wait, the seller should also be able to request cancellation if it's in_progress or requirements.
# Where is the "Cancel" button for the seller?
# It might not exist currently. Let's just add it to `_OrderDetailsSheet` or under `_buildSellerAction`.
with open('lib/screens/seller_dashboard_screen.dart', 'w') as f:
    f.write(content)

print("Updated Resolution Center for Seller")
