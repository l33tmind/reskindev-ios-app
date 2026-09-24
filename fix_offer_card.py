with open('lib/widgets/order_chat_cards.dart', 'r') as f:
    c = f.read()

import re

old_offer_buttons = """              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PRICE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: context.themeTextLight,
                    ),
                  ),
                  Text(
                    '\\$${message.offerPrice ?? 0}',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.themeTextDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );"""

new_offer_buttons = """              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PRICE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: context.themeTextLight,
                    ),
                  ),
                  Text(
                    '\\$${message.offerPrice ?? 0}',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.themeTextDark,
                    ),
                  ),
                ],
              ),
              if (!isCurrentUser)
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please accept custom offers from the website version for now.')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  ),
                  child: Text(
                    'Accept Offer',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );"""
c = c.replace(old_offer_buttons, new_offer_buttons)
with open('lib/widgets/order_chat_cards.dart', 'w') as f:
    f.write(c)

with open('lib/screens/chat_screen.dart', 'r') as f:
    c2 = f.read()

# 1. Remove from AppBar
old_appbar_action = """        actions: [
          IconButton(
            icon: Icon(
              Icons.info_outline_rounded,
              color: context.themeTextDark,
            ),
            onPressed: _showWorkspaceDetails,
            tooltip: 'Workspace Details',
          ),
          PopupMenuButton<String>("""

new_appbar_action = """        actions: [
          PopupMenuButton<String>("""
c2 = c2.replace(old_appbar_action, new_appbar_action)

# 2. Add to Input Row and remove +
old_input_row = """                  IconButton(
                    icon: Icon(Icons.add_circle_outline_rounded, color: context.themeTextLight),
                    onPressed: () {}, // Future: attachment
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),"""

new_input_row = """                  IconButton(
                    icon: Icon(Icons.info_outline_rounded, color: context.themeTextLight),
                    onPressed: _showWorkspaceDetails,
                    tooltip: 'Work Details',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),"""
c2 = c2.replace(old_input_row, new_input_row)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(c2)
