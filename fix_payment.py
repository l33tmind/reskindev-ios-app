with open('lib/widgets/order_chat_cards.dart', 'r') as f:
    c = f.read()

import re

# Update text logic
old_text = """                Text(
                  'Buyer: Please submit your requirements.\\nSeller: You may begin work once requirements are received.',
                  style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight, height: 1.4),
                ),"""

new_text = """                Text(
                  isFreelancer
                      ? 'You may begin work once the buyer submits their requirements.'
                      : 'Please submit your requirements so the seller can begin working.',
                  style: GoogleFonts.inter(fontSize: 12, color: context.themeTextDark, height: 1.4, fontWeight: FontWeight.w500),
                ),"""
c = c.replace(old_text, new_text)

# Update HELD IN ESCROW colors
old_held = """              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'HELD IN ESCROW',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                  ),
                ),
              ),"""

new_held = """              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'HELD IN ESCROW',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),"""
c = c.replace(old_held, new_held)
with open('lib/widgets/order_chat_cards.dart', 'w') as f:
    f.write(c)
