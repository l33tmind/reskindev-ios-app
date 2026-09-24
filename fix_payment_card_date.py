with open('lib/widgets/order_chat_cards.dart', 'r') as f:
    c = f.read()

import re
old_text = """                Text(
                  'Buyer: Please submit your requirements.\\nSeller: You may begin work once requirements are received.',
                  style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight, height: 1.4),
                ),"""

new_text = """                Text(
                  'Buyer: Please submit your requirements.\\nSeller: You may begin work once requirements are received.',
                  style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight, height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text(
                        'Started on ${DateFormat('MMM dd, yyyy').format(message.createdAt)}',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),"""
c = c.replace(old_text, new_text)

with open('lib/widgets/order_chat_cards.dart', 'w') as f:
    f.write(c)
