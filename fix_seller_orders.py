import re

with open('lib/screens/seller_dashboard_screen.dart', 'r') as f:
    content = f.read()

# 1. Update the Buyer UI to have a profile row and chat button
old_buyer_ui = """          const SizedBox(height: 12),
          Text('Buyer: ${order.clientName} (${order.clientEmail})', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextDark)),
          if (order.projectDetails.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Details: ${order.projectDetails}', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSellerAction(context, order),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () {
                  context.push('/chat/new', extra: {
                    'targetUserId': order.clientUid,
                    'targetUserName': order.userName,
                    'targetUserAvatar': '',
                  });
                },
                icon: const Icon(Icons.chat_bubble_outline, size: 14),
                label: const Text('Message Buyer', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _showSupportModal(context, order, order.authorId),
                style: TextButton.styleFrom(foregroundColor: Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 30)),
                child: const Text('Report Issue', style: TextStyle(fontSize: 12)),
              ),
            ],
          )"""

new_buyer_ui = """          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.themeBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.themeBorder.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                  child: Text(
                    order.clientName.isNotEmpty ? order.clientName[0].toUpperCase() : 'B',
                    style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.clientName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                      Text(order.clientEmail, style: GoogleFonts.inter(fontSize: 11, color: context.themeTextLight)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    context.push('/chat/new', extra: {
                      'targetUserId': order.clientUid,
                      'targetUserName': order.userName,
                      'targetUserAvatar': '',
                    });
                  },
                  icon: const Icon(Icons.chat_bubble_rounded),
                  color: AppTheme.primary,
                  tooltip: 'Message Buyer',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
          if (order.projectDetails.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Details: ${order.projectDetails}', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSellerAction(context, order),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => _showSupportModal(context, order, order.authorId),
              style: TextButton.styleFrom(foregroundColor: Colors.grey, padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
              child: const Text('Report Issue', style: TextStyle(fontSize: 12)),
            ),
          )"""
content = content.replace(old_buyer_ui, new_buyer_ui)


# 2. Update the Request Cancellation button to show a confirmation dialog
old_cancel_btn = """          _buildButton(context, const Color(0xFFDC2626), 'Request Cancellation', () {
            FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': 'cancel_requested_by_freelancer'});
          }),"""

new_cancel_btn = """          _buildButton(context, const Color(0xFFDC2626), 'Request Cancellation', () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Theme.of(context).cardColor,
                title: Text('Request Cancellation?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                content: const Text('Are you sure you want to request cancellation for this order? The buyer will need to approve it.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('No, Go Back'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': 'cancel_requested_by_freelancer'});
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                    child: const Text('Yes, Cancel Order'),
                  ),
                ],
              ),
            );
          }),"""
content = content.replace(old_cancel_btn, new_cancel_btn)

with open('lib/screens/seller_dashboard_screen.dart', 'w') as f:
    f.write(content)

print("Updated Seller order card UI and Cancel confirmation")
