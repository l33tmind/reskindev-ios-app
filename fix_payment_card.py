import re

with open('lib/widgets/order_chat_cards.dart', 'r') as f:
    c = f.read()

# Replace the content of _PaymentVerifiedCard
old_payment_card = """          Text(
            message.text,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: context.themeTextDark,
              height: 1.5,
            ),
          ),"""

new_payment_card = """          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment Verified by Admin',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'The escrow payment for "${message.gigTitle ?? 'your order'}" has been successfully verified.',
                  style: GoogleFonts.inter(fontSize: 13, color: context.themeTextDark, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  'Buyer: Please submit your requirements.\\nSeller: You may begin work once requirements are received.',
                  style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight, height: 1.4),
                ),
              ],
            ),
          ),"""

c = c.replace(old_payment_card, new_payment_card)

# Add fallback for requirements actionType
c = c.replace("case 'requirements_submitted':", "case 'requirements_submitted':\n      case 'requirements':")

with open('lib/widgets/order_chat_cards.dart', 'w') as f:
    f.write(c)
