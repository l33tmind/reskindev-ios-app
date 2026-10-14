import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart' as ap;
import '../theme.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ap.AuthProvider>().refreshWallet();
    });
  }

  void _showWithdrawalModal(BuildContext context, double maxAmount, bool isWallet) {
    final auth = context.read<ap.AuthProvider>();
    final amountCtrl = TextEditingController();
    final methodCtrl = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                top: 24, left: 24, right: 24,
              ),
              decoration: BoxDecoration(
                color: context.themeSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Withdraw ${isWallet ? "Wallet Funds" : "Earnings"}', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                  const SizedBox(height: 8),
                  Text('Available: \$${maxAmount.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.primary)),
                  const SizedBox(height: 24),
                  
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.inter(fontSize: 14, color: context.themeTextDark),
                    decoration: InputDecoration(
                      labelText: 'Amount (USD)',
                      labelStyle: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight),
                      filled: true,
                      fillColor: context.themeBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: methodCtrl,
                    style: GoogleFonts.inter(fontSize: 14, color: context.themeTextDark),
                    decoration: InputDecoration(
                      labelText: 'Withdrawal Method / Details (e.g. PayPal Email)',
                      labelStyle: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight),
                      filled: true,
                      fillColor: context.themeBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.account_balance),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: submitting ? null : () async {
                        final amount = double.tryParse(amountCtrl.text);
                        if (amount == null || amount <= 0 || amount > maxAmount) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount')));
                          return;
                        }
                        if (methodCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter withdrawal details')));
                          return;
                        }
                        
                        setState(() => submitting = true);
                        try {
                          final batch = FirebaseFirestore.instance.batch();
                          final userRef = FirebaseFirestore.instance.collection('users').doc(auth.user!.uid);
                          
                          if (isWallet) {
                            batch.update(userRef, {
                              'walletBalance': FieldValue.increment(-amount),
                            });
                          }
                          
                          final withdrawRef = FirebaseFirestore.instance.collection('withdrawals').doc();
                          batch.set(withdrawRef, {
                            'id': withdrawRef.id,
                            'amount': amount,
                            'freelancerId': auth.user!.uid,
                            'freelancerName': auth.displayName,
                            'freelancerEmail': auth.email,
                            'method': methodCtrl.text.trim(),
                            'source': isWallet ? 'wallet' : 'earnings',
                            'status': 'pending',
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          
                          await batch.commit();
                          auth.refreshWallet();
                          
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal request submitted successfully!')));
                          }
                        } catch (e) {
                          setState(() => submitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: submitting 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Submit Request', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();
    final isDesktop = MediaQuery.of(context).size.width > 800;

    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wallet')),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        title: Text(auth.role == 'freelancer' || auth.role == 'admin' ? 'Wallet & Earnings' : 'Wallet', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
        backgroundColor: context.themeSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: context.themeTextDark),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: EdgeInsets.all(isDesktop ? 32 : 16),
            children: [
              // Wallet Card
              _buildBalanceCard(
                title: 'Wallet Balance',
                amount: auth.walletBalance,
                icon: Icons.account_balance_wallet,
                color: Colors.green,
                onWithdraw: () => _showWithdrawalModal(context, auth.walletBalance, true),
              ),
              const SizedBox(height: 24),
              
              // Earnings Card (if applicable)
              if (auth.role == 'freelancer' || auth.role == 'admin')
                _buildBalanceCard(
                  title: 'Available Earnings',
                  amount: auth.availableToWithdraw,
                  icon: Icons.monetization_on,
                  color: Colors.orange,
                  onWithdraw: () => _showWithdrawalModal(context, auth.availableToWithdraw, false),
                  subtitle: 'Note: Withdrawals from earnings may deduct from available earnings directly if handled manually by admin, but they do not automatically debit from walletBalance.',
                ),
                
              const SizedBox(height: 32),
              Text('Recent Withdrawals', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark)),
              const SizedBox(height: 16),
              
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('withdrawals')
                    .where('freelancerId', isEqualTo: auth.user!.uid)
                    
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text('Error loading history');
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator.adaptive());
                  
                  final docs = snapshot.data!.docs.toList();
                  docs.sort((a, b) {
                    final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                    final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                    if (aTime == null || bTime == null) return 0;
                    return bTime.compareTo(aTime);
                  });
                  if (docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: context.themeSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.themeBorder),
                      ),
                      child: Center(
                        child: Text('No withdrawal history found.', style: GoogleFonts.inter(color: context.themeTextLight)),
                      ),
                    );
                  }
                  
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                      final status = data['status'] ?? 'pending';
                      final source = data['source'] ?? 'earnings';
                      final date = (data['createdAt'] as Timestamp?)?.toDate();
                      
                      Color statusColor;
                      switch (status) {
                        case 'approved': statusColor = Colors.green; break;
                        case 'rejected': statusColor = Colors.red; break;
                        default: statusColor = Colors.orange; break;
                      }
                      
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.themeSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.themeBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: source == 'wallet' ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(source == 'wallet' ? Icons.account_balance_wallet : Icons.monetization_on, size: 20, color: source == 'wallet' ? Colors.green : Colors.orange),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    source == 'wallet' ? 'Wallet Withdrawal' : 'Earnings Withdrawal',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextDark),
                                  ),
                                  if (date != null)
                                    Text('${date.day}/${date.month}/${date.year}', style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('-\$${amount.toStringAsFixed(2)}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: context.themeTextDark)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(status.toString().toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard({
    required String title, 
    required double amount, 
    required IconData icon, 
    required Color color, 
    required VoidCallback onWithdraw,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: context.themeTextLight)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('\$${amount.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: context.themeTextDark)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (subtitle != null) ...[
            Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: amount > 0 ? onWithdraw : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Withdraw Funds', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
