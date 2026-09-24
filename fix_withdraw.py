import re

with open('lib/screens/seller_dashboard_screen.dart', 'r') as f:
    content = f.read()

# Replace the StreamBuilder for orders to also include withdrawals if possible.
# Actually, it's easier to just fetch withdrawals in a separate stream or Future inside the modal!
# Wait, the UI should show the correct available balance in the text.
old_stats = """                  int completedOrders = 0;
                  double totalEarnings = 0;
                  if (orderSnap.hasData) {
                    for (var doc in orderSnap.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['status'] == 'completed') {
                        completedOrders++;
                        totalEarnings += (data['price'] as num?)?.toDouble() ?? 0;
                      }
                    }
                  }"""

new_stats = """                  int completedOrders = 0;
                  double totalEarnings = 0;
                  if (orderSnap.hasData) {
                    for (var doc in orderSnap.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['status'] == 'completed') {
                        completedOrders++;
                        totalEarnings += ((data['price'] as num?)?.toDouble() ?? 0) * 0.8; // Net earnings
                      }
                    }
                  }"""
content = content.replace(old_stats, new_stats)

old_btn = """                            OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                foregroundColor: context.themeTextDark,
                                side: BorderSide(color: context.themeBorder),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: Text('Withdraw Funds', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                            )"""

new_btn = """                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('withdrawals').where('freelancerId', isEqualTo: uid).snapshots(),
                              builder: (context, withdrawSnap) {
                                double withdrawn = 0;
                                if (withdrawSnap.hasData) {
                                  for (var wDoc in withdrawSnap.data!.docs) {
                                    final wData = wDoc.data() as Map<String, dynamic>;
                                    // if it's pending or approved, we deduct it
                                    if (wData['status'] != 'rejected') {
                                      withdrawn += (wData['amount'] as num?)?.toDouble() ?? 0;
                                    }
                                  }
                                }
                                final availableForWithdrawal = totalEarnings - withdrawn;
                                
                                return Column(
                                  children: [
                                    if (withdrawn > 0) ...[
                                      Text('Available: \\$${availableForWithdrawal.toStringAsFixed(2)} | Withdrawn/Pending: \\$${withdrawn.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
                                      const SizedBox(height: 12),
                                    ],
                                    OutlinedButton(
                                      onPressed: () => _showWithdrawalModal(context, availableForWithdrawal, uid, auth.displayName, auth.user?.email),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: context.themeTextDark,
                                        side: BorderSide(color: context.themeBorder),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                      child: Text('Withdraw Funds', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                );
                              }
                            )"""
content = content.replace(old_btn, new_btn)

with open('lib/screens/seller_dashboard_screen.dart', 'w') as f:
    f.write(content)

print("Added Withdrawal Stats & Button logic")
