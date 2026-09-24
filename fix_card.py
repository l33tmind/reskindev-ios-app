with open('lib/widgets/order_chat_cards.dart', 'r') as f:
    c = f.read()

old_btn = """                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text('View Gig'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        minimumSize: const Size(0, 28),
                        textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),"""

new_btn = """                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                      label: const Text('View Gig'),
                      style: TextButton.styleFrom(
                        foregroundColor: context.themeTextLight,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        minimumSize: const Size(0, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),"""

c = c.replace(old_btn, new_btn)

old_card = """    return Container(
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.themeBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),"""

new_card = """    return Container(
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),"""
c = c.replace(old_card, new_card)

with open('lib/widgets/order_chat_cards.dart', 'w') as f:
    f.write(c)
