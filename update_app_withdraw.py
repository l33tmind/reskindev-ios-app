import re

with open('lib/screens/seller_dashboard_screen.dart', 'r') as f:
    c = f.read()

# 1. Update the warning text in modal to mention $3 charge
old_warning = """                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withValues(alpha: 0.2))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Note: Your ReskinDev account name and your Payoneer account name must be exactly the same. Otherwise, the withdrawal will be rejected.', style: GoogleFonts.inter(fontSize: 12, color: Colors.blue.shade700))),
                      ],
                    ),
                  ),"""

new_warning = """                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withValues(alpha: 0.2))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Note: Your ReskinDev account name and your Payoneer account name must be exactly the same. A fixed \$3 withdrawal fee will be applied.', style: GoogleFonts.inter(fontSize: 12, color: Colors.blue.shade700))),
                      ],
                    ),
                  ),"""

c = c.replace(old_warning, new_warning)

# 2. Update the Firestore payload
old_payload = """                          await FirebaseFirestore.instance.collection('withdrawals').add({
                            'freelancerId': uid,
                            'freelancerName': displayName,
                            'email': payoneerEmail, // Next.js admin uses this field
                            'amount': amount,
                            'status': 'pending',
                            'createdAt': FieldValue.serverTimestamp(),
                          });"""

new_payload = """                          await FirebaseFirestore.instance.collection('withdrawals').add({
                            'freelancerId': uid,
                            'freelancerName': displayName,
                            'email': payoneerEmail, // Next.js admin uses this field
                            'amount': amount,
                            'charge': 3.0,
                            'netAmount': amount - 3.0,
                            'status': 'pending',
                            'createdAt': FieldValue.serverTimestamp(),
                          });"""

c = c.replace(old_payload, new_payload)

with open('lib/screens/seller_dashboard_screen.dart', 'w') as f:
    f.write(c)
