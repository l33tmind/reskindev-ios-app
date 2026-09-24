import re

with open('lib/screens/seller_dashboard_screen.dart', 'r') as f:
    content = f.read()

old_action = """    } else if (order.status == 'delivered') {
      return _buildLabel(const Color(0xFFD97706), const Color(0xFFFEF3C7), const Color(0xFFFDE68A), 'Waiting for Client Approval');
    } else if (order.status == 'completed') {
      return _buildLabel(const Color(0xFF059669), const Color(0xFFD1FAE5), const Color(0xFFA7F3D0), 'Order Completed');
    } else if (order.status == 'cancelled') {"""

new_action = """    } else if (order.status == 'delivered') {
      return _buildLabel(const Color(0xFFD97706), const Color(0xFFFEF3C7), const Color(0xFFFDE68A), 'Waiting for Client Approval');
    } else if (order.status == 'completed') {
      if (order.hasReview && !order.isReviewPublic) {
        return _buildButton(context, const Color(0xFF8B5CF6), 'Rate Buyer to see review', () {
          _showSellerRatingModal(context, order);
        });
      }
      return _buildLabel(const Color(0xFF059669), const Color(0xFFD1FAE5), const Color(0xFFA7F3D0), 'Order Completed');
    } else if (order.status == 'cancelled') {"""
content = content.replace(old_action, new_action)

with open('lib/screens/seller_dashboard_screen.dart', 'w') as f:
    f.write(content)

print("Updated _buildSellerAction for Blind Review")
