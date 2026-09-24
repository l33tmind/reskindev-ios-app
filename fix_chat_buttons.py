import re

# 1. Update my_orders_screen.dart (Buyer viewing order)
with open('lib/screens/my_orders_screen.dart', 'r') as f:
    content = f.read()

old_support = """                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showSupportModal(context, order, order.clientUid);
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                      child: const Text('Report Issue / Contact Support'),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),"""

new_support = """                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/chat/new', extra: {
                          'targetUserId': order.authorId,
                          'targetUserName': 'Freelancer',
                          'targetUserAvatar': '',
                        });
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Message Seller'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                        foregroundColor: AppTheme.primary,
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showSupportModal(context, order, order.clientUid);
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                      child: const Text('Report Issue / Contact Support'),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),"""
content = content.replace(old_support, new_support)
with open('lib/screens/my_orders_screen.dart', 'w') as f:
    f.write(content)


# 2. Update seller_dashboard_screen.dart (Seller viewing order)
with open('lib/screens/seller_dashboard_screen.dart', 'r') as f:
    content = f.read()

old_seller_support = """          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _showSupportModal(context, order, order.authorId),
              style: TextButton.styleFrom(foregroundColor: Colors.grey, padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
              child: const Text('Report Issue', style: TextStyle(fontSize: 12)),
            ),
          )
        ],
      ),
    );"""

new_seller_support = """          const SizedBox(height: 8),
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
          )
        ],
      ),
    );"""
content = content.replace(old_seller_support, new_seller_support)
with open('lib/screens/seller_dashboard_screen.dart', 'w') as f:
    f.write(content)

print("Added Chat buttons to orders")
