with open('lib/screens/inbox_screen.dart', 'r') as f:
    c = f.read()

import re

# Fix inbox screen
old_name = "final String name = chat.orderId != null ? 'Order #${chat.orderId!.length > 6 ? chat.orderId!.substring(0, 6) : chat.orderId!.toUpperCase()}' : (otherUser['name']?.toString() ?? 'Unknown');"
new_name = "final String otherName = otherUser['name']?.toString() ?? 'Unknown';\n                    final String name = chat.orderId != null ? '$otherName (Order #${chat.orderId!.length > 6 ? chat.orderId!.substring(0, 6).toUpperCase() : chat.orderId!.toUpperCase()})' : otherName;"
c = c.replace(old_name, new_name)
with open('lib/screens/inbox_screen.dart', 'w') as f:
    f.write(c)

with open('lib/screens/chat_screen.dart', 'r') as f:
    c2 = f.read()

# Fix chat screen app bar
old_appbar = "title: Text(_currentOrderId != null ? 'Order #${_currentOrderId!.length > 6 ? _currentOrderId!.substring(0,6) : _currentOrderId!.toUpperCase()}' : (widget.targetUserName ?? 'Chat'),"
new_appbar = "title: Text(_currentOrderId != null ? '${widget.targetUserName ?? 'Unknown'} (Order #${_currentOrderId!.length > 6 ? _currentOrderId!.substring(0,6).toUpperCase() : _currentOrderId!.toUpperCase()})' : (widget.targetUserName ?? 'Chat'),"
c2 = c2.replace(old_appbar, new_appbar)
with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(c2)

with open('lib/widgets/workspace_details_sheet.dart', 'r') as f:
    c3 = f.read()

# Fix workspace details sheet order ID
old_order_id = "Text('#${order.id}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextDark)),"
new_order_id = "Text(order.id != null ? '#${order.id!.length > 6 ? order.id!.substring(0,6).toUpperCase() : order.id!.toUpperCase()}' : '#', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextDark)),"
c3 = c3.replace(old_order_id, new_order_id)
with open('lib/widgets/workspace_details_sheet.dart', 'w') as f:
    f.write(c3)
