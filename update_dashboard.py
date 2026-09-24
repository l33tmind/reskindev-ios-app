with open('lib/screens/seller_dashboard_screen.dart', 'r') as f:
    c = f.read()

import re

# 1. Update the overall calculation in _SellerOverview build method
old_calc = """                  int completedOrders = 0;
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

new_calc = """                  int completedOrders = 0;
                  double totalEarnings = 0;
                  double availableToWithdraw = 0;
                  double pendingClearance = 0;
                  final now = DateTime.now();

                  if (orderSnap.hasData) {
                    for (var doc in orderSnap.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['status'] == 'completed') {
                        completedOrders++;
                        final earned = ((data['price'] as num?)?.toDouble() ?? 0) * 0.8;
                        totalEarnings += earned;
                        
                        DateTime? completedAt;
                        if (data['completedAt'] is Timestamp) {
                          completedAt = (data['completedAt'] as Timestamp).toDate();
                        } else if (data['completedAt'] is String) {
                          completedAt = DateTime.tryParse(data['completedAt']);
                        }
                        
                        if (completedAt != null && now.difference(completedAt).inDays < 15) {
                          pendingClearance += earned;
                        } else {
                          availableToWithdraw += earned;
                        }
                      }
                    }
                  }"""

c = c.replace(old_calc, new_calc)

# 2. Update the UI logic for Available balance in the button area
old_button_area = """                                final availableForWithdrawal = totalEarnings - withdrawn;
                                
                                return Column(
                                  children: [
                                    if (withdrawn > 0) ...[
                                      Text('Available: \\$${availableForWithdrawal.toStringAsFixed(2)} | Withdrawn/Pending: \\$${withdrawn.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
                                      const SizedBox(height: 12),
                                    ],
                                    OutlinedButton(
                                      onPressed: () => _showWithdrawalModal(context, availableForWithdrawal, uid, auth.displayName, auth.user?.email),"""

new_button_area = """                                final availableForWithdrawal = availableToWithdraw - withdrawn;
                                
                                return Column(
                                  children: [
                                    Text('Available: \\$${availableForWithdrawal.toStringAsFixed(2)} | Pending 15-Days: \\$${pendingClearance.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
                                    if (withdrawn > 0) ...[
                                      const SizedBox(height: 4),
                                      Text('Withdrawn/Processing: \\$${withdrawn.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 12, color: Colors.orange)),
                                    ],
                                    const SizedBox(height: 12),
                                    OutlinedButton(
                                      onPressed: () => _showWithdrawalModal(context, availableForWithdrawal, uid, auth.displayName, auth.user?.email),"""

c = c.replace(old_button_area, new_button_area)

# 3. Update Modal Minimum Withdrawal from $50 to $20 to match website
c = c.replace("Amount to Withdraw (Min $50)", "Amount to Withdraw (Min $20)")
c = c.replace("amount < 50", "amount < 20")
c = c.replace("Minimum withdrawal amount is $50", "Minimum withdrawal amount is $20")

# 4. Fix database connection inside Modal (email field matching website)
old_db_save = """                          await FirebaseFirestore.instance.collection('withdrawals').add({
                            'freelancerId': uid,
                            'freelancerName': displayName,
                            'email': email ?? '',
                            'payoneerEmail': payoneerEmail,
                            'amount': amount,
                            'status': 'pending',
                            'createdAt': FieldValue.serverTimestamp(),
                          });"""

new_db_save = """                          await FirebaseFirestore.instance.collection('withdrawals').add({
                            'freelancerId': uid,
                            'freelancerName': displayName,
                            'email': payoneerEmail, // Next.js admin uses this field
                            'amount': amount,
                            'status': 'pending',
                            'createdAt': FieldValue.serverTimestamp(),
                          });"""

c = c.replace(old_db_save, new_db_save)

with open('lib/screens/seller_dashboard_screen.dart', 'w') as f:
    f.write(c)

