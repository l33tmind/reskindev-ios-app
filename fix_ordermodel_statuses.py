import re

with open('lib/models/order_model.dart', 'r') as f:
    content = f.read()

# statusColor
old_color = """      case 'completed':     return const Color(0xFF1BCA75); // Green
      case 'cancelled':     return const Color(0xFFEF4444); // Red"""
new_color = """      case 'completed':     return const Color(0xFF1BCA75); // Green
      case 'cancelled':     return const Color(0xFFEF4444); // Red
      case 'cancel_requested_by_buyer': return const Color(0xFFF97316); // Orange
      case 'cancel_requested_by_freelancer': return const Color(0xFFF97316); // Orange
      case 'disputed':      return const Color(0xFFDC2626); // Dark Red"""
content = content.replace(old_color, new_color)

# statusLabel
old_label = """      case 'completed':     return 'Completed';
      case 'cancelled':     return 'Cancelled';"""
new_label = """      case 'completed':     return 'Completed';
      case 'cancelled':     return 'Cancelled';
      case 'cancel_requested_by_buyer': return 'Cancel Requested (Buyer)';
      case 'cancel_requested_by_freelancer': return 'Cancel Requested (Seller)';
      case 'disputed':      return 'Disputed';"""
content = content.replace(old_label, new_label)

# statusIcon
old_icon = """      case 'completed':     return Icons.check_circle_outline;
      case 'cancelled':     return Icons.cancel_outlined;"""
new_icon = """      case 'completed':     return Icons.check_circle_outline;
      case 'cancelled':     return Icons.cancel_outlined;
      case 'cancel_requested_by_buyer': return Icons.help_outline;
      case 'cancel_requested_by_freelancer': return Icons.help_outline;
      case 'disputed':      return Icons.warning_amber_rounded;"""
content = content.replace(old_icon, new_icon)

with open('lib/models/order_model.dart', 'w') as f:
    f.write(content)

print("Added Resolution Center statuses to OrderModel")
