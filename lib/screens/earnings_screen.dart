import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../models/order_model.dart';
import '../theme.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        title: Text('Earnings', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
        backgroundColor: context.themeSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: context.themeTextDark),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').where('authorId', isEqualTo: auth.user!.uid).where('status', isEqualTo: 'completed').snapshots(),
        builder: (context, orderSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('withdrawals').where('freelancerId', isEqualTo: auth.user!.uid).snapshots(),
            builder: (context, withdrawSnap) {
              if (orderSnap.connectionState == ConnectionState.waiting || withdrawSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator.adaptive());
              }

              if (orderSnap.hasError) {
                return Center(child: Text('Error: \${orderSnap.error}'));
              }

              double pendingClearance = 0;
              double availableBalance = 0;
              double totalEarned = 0;
              double totalWithdrawn = 0;

              final now = DateTime.now();

              if (orderSnap.hasData) {
                for (var doc in orderSnap.data!.docs) {
                  final order = OrderModel.fromFirestore(doc);
                  final double price = order.price;
                  totalEarned += price;

                  if (order.completedAt != null) {
                    final daysSinceCompletion = now.difference(order.completedAt!).inDays;
                    if (daysSinceCompletion < 15) {
                      pendingClearance += price;
                    } else {
                      availableBalance += price;
                    }
                  } else {
                    pendingClearance += price;
                  }
                }
              }
              
              if (withdrawSnap.hasData) {
                for (var doc in withdrawSnap.data!.docs) {
                  final amount = (doc.data() as Map)['amount'] as num?;
                  if (amount != null) totalWithdrawn += amount.toDouble();
                }
              }
              
              availableBalance -= totalWithdrawn;
              if (availableBalance < 0) availableBalance = 0;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBalanceCard(context, 'Available for Withdrawal', availableBalance, true),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildBalanceCard(context, 'Pending Clearance', pendingClearance, false, isSmall: true)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildBalanceCard(context, 'Total Earned', totalEarned, false, isSmall: true)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text('How it works', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                    const SizedBox(height: 12),
                    _buildInfoTile(
                      context,
                      Icons.check_circle_outline,
                      'Order Completion',
                      'When a buyer approves your delivery, the order is marked as completed.',
                    ),
                    _buildInfoTile(
                      context,
                      Icons.timer_outlined,
                      '15-Day Clearance',
                      'Funds remain in "Pending Clearance" for 15 days after completion to ensure buyer satisfaction.',
                    ),
                    _buildInfoTile(
                      context,
                      Icons.account_balance_wallet_outlined,
                      'Withdrawal',
                      'After 15 days, funds move to your Available Balance and can be withdrawn.',
                    ),
                    const SizedBox(height: 32),
                    if (availableBalance >= 50)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showWithdrawalModal(context, availableBalance, auth.user!.uid, auth.displayName ?? '', auth.user!.email ?? ''),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: const Text('Withdraw Funds'),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: context.themeSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.themeBorder)),
                        child: Text('Minimum \$50 required to withdraw.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: context.themeTextLight)),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showWithdrawalModal(BuildContext context, double available, String uid, String name, String email) {
    final amountCtrl = TextEditingController();
    final payoneerCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: context.themeCard,
        title: Text('Withdraw to Payoneer', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available: \$${available.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary)),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: context.themeTextDark),
              decoration: const InputDecoration(labelText: 'Amount to Withdraw (\$)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: payoneerCtrl,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: context.themeTextDark),
              decoration: const InputDecoration(labelText: 'Payoneer Email'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              final payEmail = payoneerCtrl.text.trim();
              
              if (amount < 50 || amount > available) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount. Must be >= \$50 and <= available balance.'), backgroundColor: Colors.red));
                return;
              }
              if (payEmail.isEmpty || !payEmail.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Payoneer email.'), backgroundColor: Colors.red));
                return;
              }
              
              Navigator.pop(c);
              await FirebaseFirestore.instance.collection('withdrawals').add({
                'freelancerId': uid,
                'freelancerName': name,
                'email': email,
                'payoneerEmail': payEmail,
                'amount': amount,
                'status': 'pending',
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal request submitted successfully!')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, String title, double amount, bool isPrimary, {bool isSmall = false}) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 24),
      decoration: BoxDecoration(
        color: isPrimary ? AppTheme.primary : context.themeSurface,
        borderRadius: BorderRadius.circular(16),
        border: isPrimary ? null : Border.all(color: context.themeBorder),
        boxShadow: isPrimary
            ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: isSmall ? 12 : 14, color: isPrimary ? Colors.white70 : context.themeTextLight)),
          const SizedBox(height: 8),
          Text('\$${amount.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: isSmall ? 24 : 36, fontWeight: FontWeight.bold, color: isPrimary ? Colors.white : context.themeTextDark)),
        ],
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextDark)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
