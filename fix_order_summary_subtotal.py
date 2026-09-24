import re

with open('lib/screens/order_form_screen.dart', 'r') as f:
    content = f.read()

old_summary_ui = """                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Service Fee (${serviceFeePct.toStringAsFixed(0)}%)',"""
new_summary_ui = """                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal',
                                  style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
                              Text('\$${discountedPrice.toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Service Fee (${serviceFeePct.toStringAsFixed(0)}%)',"""
content = content.replace(old_summary_ui, new_summary_ui)

with open('lib/screens/order_form_screen.dart', 'w') as f:
    f.write(content)

print("Added Subtotal row")
