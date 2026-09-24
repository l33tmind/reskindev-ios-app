import re

with open('lib/screens/seller_profile_screen.dart', 'r') as f:
    c = f.read()

old_block = """                    if (order.deliveryLink.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.link_rounded, color: AppTheme.primary, size: 16),
                          const SizedBox(width: 4),
                          Expanded(child: Text('Delivery Link Available', style: GoogleFonts.inter(color: AppTheme.primary, fontSize: 13, decoration: TextDecoration.underline))),
                        ],
                      )
                    ]"""

c = c.replace(old_block, "")

with open('lib/screens/seller_profile_screen.dart', 'w') as f:
    f.write(c)
