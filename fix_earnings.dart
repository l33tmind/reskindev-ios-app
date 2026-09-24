import 'dart:io';

void main() {
  final file = File('lib/screens/earnings_screen.dart');
  var content = file.readAsStringSync();
  
  // 1. We need to nest a StreamBuilder for 'withdrawals'
  final oldStreamBuilder = '''
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('authorId', isEqualTo: auth.user!.uid)
            .where('status', isEqualTo: 'completed')
            .snapshots(),
        builder: (context, snapshot) {
''';
  final newStreamBuilder = '''
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').where('authorId', isEqualTo: auth.user!.uid).where('status', isEqualTo: 'completed').snapshots(),
        builder: (context, orderSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('withdrawals').where('freelancerId', isEqualTo: auth.user!.uid).snapshots(),
            builder: (context, withdrawSnap) {
              if (orderSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator.adaptive());
''';
  if (content.contains(oldStreamBuilder)) {
    content = content.replaceFirst(oldStreamBuilder, newStreamBuilder);
  }

  // 2. Change the rest of the stream handling
  final oldChecks = '''
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: \${snapshot.error}'));
          }

          double pendingClearance = 0;
          double availableBalance = 0;
          double totalEarned = 0;

          final now = DateTime.now();

          for (var doc in snapshot.data!.docs) {
''';
  final newChecks = '''
              double pendingClearance = 0;
              double availableBalance = 0;
              double totalEarned = 0;
              double totalWithdrawn = 0;

              final now = DateTime.now();

              if (orderSnap.hasData) {
                for (var doc in orderSnap.data!.docs) {
''';
  if (content.contains(oldChecks)) {
    content = content.replaceFirst(oldChecks, newChecks);
  }

  // 3. Deduct withdrawals
  final oldFallback = '''
              // Fallback if completedAt is missing but status is completed
              pendingClearance += price;
            }
          }

          return SingleChildScrollView(
''';
  final newFallback = '''
                  // Fallback if completedAt is missing but status is completed
                  pendingClearance += price;
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
''';
  if (content.contains(oldFallback)) {
    content = content.replaceFirst(oldFallback, newFallback);
  }

  // 4. Add Withdraw button and close the nested StreamBuilder
  final oldScroll = '''
                _buildInfoTile(
                  context,
                  Icons.account_balance_wallet_outlined,
                  'Withdrawal',
                  'After 15 days, funds move to your Available Balance and can be withdrawn.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
''';
  final newScroll = '''
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
''';
  if (content.contains(oldScroll)) {
    content = content.replaceFirst(oldScroll, newScroll);
  }

  // 5. Insert _showWithdrawalModal
  final modal = '''
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
            Text('Available: \$\${available.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary)),
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal request submitted successfully!')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }
''';

  content = content.replaceFirst('  Widget _buildBalanceCard', modal + '\n  Widget _buildBalanceCard');

  file.writeAsStringSync(content);
  print('Earnings screen updated');
}
