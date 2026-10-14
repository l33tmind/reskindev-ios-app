import '../models/gig_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/earnings_chart.dart';

import '../models/order_model.dart';
import '../services/order_chat_nav.dart';
import '../widgets/user_avatar.dart';
import '../widgets/countdown_timer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../services/notification_service.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/chat_provider.dart' as chat;
import 'manage_services_view.dart';
import 'admin_orders_view.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();



    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        backgroundColor: context.themeSurface,
        title: Text('Seller Dashboard', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: context.themeTextDark)),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _Tab(label: 'Dashboard', isActive: _selectedIndex == 0, onTap: () => setState(() => _selectedIndex = 0)),
                _Tab(label: 'My Gigs', isActive: _selectedIndex == 1, onTap: () => setState(() => _selectedIndex = 1)),
                _Tab(label: 'My Orders', isActive: _selectedIndex == 2, onTap: () => setState(() => _selectedIndex = 2)),
              ],
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _SellerOverview(
            onNavigateGigs: () => setState(() => _selectedIndex = 1),
            onNavigateOrders: () => setState(() => _selectedIndex = 2),
          ),
          const _SellerGigsView(),
          const _SellerOrdersView(),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? null : Border.all(color: context.themeBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isActive ? Colors.white : context.themeTextLight,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SellerOverview extends StatelessWidget {
  final VoidCallback onNavigateGigs;
  final VoidCallback onNavigateOrders;
  const _SellerOverview({required this.onNavigateGigs, required this.onNavigateOrders});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome back, ${auth.displayName}', style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
          const SizedBox(height: 24),
          
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('services').where('authorId', isEqualTo: uid).snapshots(),
            builder: (context, gigSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('orders').where('authorId', isEqualTo: uid).snapshots(),
                builder: (context, orderSnap) {
                  int activeGigs = 0;
                  if (gigSnap.hasData) {
                    activeGigs = gigSnap.data!.docs.where((d) => (d.data() as Map)['status'] == 'active' || (d.data() as Map)['status'] == 'published').length;
                  }

                  int completedOrders = 0;
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
                  }

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _StatCard(title: 'ACTIVE GIGS', value: activeGigs.toString(), icon: Icons.list_alt, color: Colors.blue)),
                          const SizedBox(width: 16),
                          Expanded(child: _StatCard(title: 'COMPLETED ORDERS', value: completedOrders.toString(), icon: Icons.check_circle_outline, color: Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: context.themeSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.themeBorder),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.attach_money, color: Colors.orange),
                            ),
                            const SizedBox(height: 12),
                            Text('\$${totalEarnings.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                            Text('TOTAL EARNINGS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: context.themeTextLight)),
                            const SizedBox(height: 16),
                            StreamBuilder<QuerySnapshot>(
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
                                final availableForWithdrawal = availableToWithdraw - withdrawn;
                                
                                return Column(
                                  children: [
                                    Text('Available: \$${availableForWithdrawal.toStringAsFixed(2)} | Pending 15-Days: \$${pendingClearance.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
                                    if (withdrawn > 0) ...[
                                      const SizedBox(height: 4),
                                      Text('Withdrawn/Processing: \$${withdrawn.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 12, color: Colors.orange)),
                                    ],
                                    const SizedBox(height: 12),
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
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      EarningsChart(orders: orderSnap.data?.docs ?? const []),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.themeBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: context.themeTextDark)),
          Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: context.themeTextLight)),
        ],
      ),
    );
  }
}


class _SellerGigsView extends StatelessWidget {
  const _SellerGigsView();

  @override
  Widget build(BuildContext context) {
    final uid = context.read<ap.AuthProvider>().user?.uid;
    if (uid == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('services').where('authorId', isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs.where((d) => (d.data() as Map)['status'] != 'deleted').toList();
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('My Gigs', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/seller/edit-gig'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Gig'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Manage the services you offer', style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
              const SizedBox(height: 24),
              if (docs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.dashboard_customize_outlined, size: 64, color: context.themeBorder),
                        const SizedBox(height: 16),
                        Text('No gigs found', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                        const SizedBox(height: 8),
                        Text('Create your first gig to start selling.', style: GoogleFonts.inter(color: context.themeTextLight)),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => context.push('/seller/edit-gig'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                          child: const Text('Create Gig'),
                        )
                      ],
                    ),
                  ),
                ),
              for (var doc in docs) _buildGigCard(context, doc),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGigCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final imageUrl = data['imageUrl'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final status = data['status'] as String? ?? 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: context.themeBorder.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  Image.network(imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover),
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'active' || status == 'published' ? const Color(0xFF10B981) : Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(status.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'active' || status == 'published' ? const Color(0xFF10B981).withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(status.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: status == 'active' || status == 'published' ? const Color(0xFF10B981) : Colors.orange)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  title,
                  style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: context.themeTextDark, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final gig = GigModel.fromFirestore(doc);
                          context.push('/seller/edit-gig', extra: gig);
                        },
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Edit Gig'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                          foregroundColor: AppTheme.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => _confirmDelete(context, doc.id),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Gig?'),
        content: const Text('Are you sure you want to delete this gig?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('services').doc(docId).update({'isActive': false, 'status': 'deleted'});
              Navigator.pop(c);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

  Widget _buildCountdownTimer(BuildContext context, DateTime startedAt, int deliveryDays) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final deadline = startedAt.add(Duration(days: deliveryDays));
        final diff = deadline.difference(DateTime.now());
        
        if (diff.isNegative) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.timer_off_outlined, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text('Delivery is Late!', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
              ],
            ),
          );
        }

        final days = diff.inDays;
        final hours = (diff.inHours % 24).toString().padLeft(2, '0');
        final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.05),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer_outlined, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Time Left:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextDark, fontSize: 13)),
                ],
              ),
              Text('${days}d ${hours}h ${minutes}m ${seconds}s', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 16)),
            ],
          ),
        );
      },
    );
  }

void _showSupportModal(BuildContext context, OrderModel order, String reportedBy) {
  final subjCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: context.themeCard,
      title: Text('Contact Support', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Describe the issue you are facing with this order.', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
            const SizedBox(height: 16),
            TextField(
              controller: subjCtrl,
              style: TextStyle(color: context.themeTextDark),
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 4,
              style: TextStyle(color: context.themeTextDark),
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (subjCtrl.text.isEmpty || descCtrl.text.isEmpty) return;
            Navigator.pop(c);
            await FirebaseFirestore.instance.collection('support_tickets').add({
              'orderId': order.id,
              'gigTitle': order.gigTitle,
              'reportedByUid': reportedBy,
              'subject': subjCtrl.text,
              'description': descCtrl.text,
              'status': 'open',
              'createdAt': FieldValue.serverTimestamp(),
            });
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support ticket created. We will contact you soon.')));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          child: const Text('Submit Ticket'),
        ),
      ],
    ),
  );
}

class _SellerOrdersView extends StatelessWidget {
  const _SellerOrdersView();

  @override
  Widget build(BuildContext context) {
    final uid = context.read<ap.AuthProvider>().user?.uid;
    if (uid == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').where('authorId', isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.red))));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          
          DateTime? parseD(dynamic val) {
            if (val == null) return null;
            if (val is Timestamp) return val.toDate();
            if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
            if (val is String) return DateTime.tryParse(val);
            return null;
          }
          
          final timeA = parseD(dataA['createdAt']);
          final timeB = parseD(dataB['createdAt']);
          if (timeA == null || timeB == null) return 0;
          return timeB.compareTo(timeA); // Descending
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Orders', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: context.themeTextDark)),
              const SizedBox(height: 8),
              Text('View your assigned orders and update delivery status', style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
              const SizedBox(height: 24),
              if (docs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: context.themeBorder),
                        const SizedBox(height: 16),
                        Text('No orders yet', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                        const SizedBox(height: 8),
                        Text('When clients purchase your gigs, they will appear here.', style: GoogleFonts.inter(color: context.themeTextLight), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              for (var doc in docs) _buildOrderCard(context, doc),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(BuildContext context, QueryDocumentSnapshot doc) {
    final order = OrderModel.fromFirestore(doc);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.themeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.gigTitle, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                    Text('${order.packageName} Package • \$${order.price.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: order.statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(order.statusLabel.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: order.statusColor)),
              ),
            ],
          ),
          if (order.status == 'in_progress' && order.startedAt != null) ...[
            const SizedBox(height: 12),
            _buildCountdownTimer(context, order.startedAt!, order.deliveryDays),
          ],
          if (order.status == 'revision') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Revision Requested', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.red.shade800, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(order.revisionNote.isNotEmpty ? order.revisionNote : 'The buyer has requested modifications.', style: GoogleFonts.inter(color: Colors.red.shade800, fontSize: 13)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.themeBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.themeBorder.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                UserAvatar(uid: order.clientUid, name: order.clientName, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.clientName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                      Text(order.clientEmail, style: GoogleFonts.inter(fontSize: 11, color: context.themeTextLight)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => openOrderChat(context, order),
                  icon: const Icon(Icons.chat_bubble_rounded),
                  color: AppTheme.primary,
                  tooltip: 'Message Buyer',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
          if (order.projectDetails.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Details: ${order.projectDetails}', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSellerAction(context, order),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => _showSupportModal(context, order, order.authorId),
              style: TextButton.styleFrom(foregroundColor: Colors.grey, padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
              child: const Text('Report Issue', style: TextStyle(fontSize: 12)),
            ),
          )
        ],
      ),
    );
  }
  Widget _buildSellerAction(BuildContext context, OrderModel order) {
    if (order.status == 'pending_payment') {
      return _buildLabel(const Color(0xFFDC2626), const Color(0xFFFEF2F2), const Color(0xFFFECACA), 'Waiting for Payment (Escrow)');
    } else if (['requirements', 'pending', 'processing', 'in_progress', 'revision'].contains(order.status)) {
      // Delivering happens in the order chat (its top panel), the one place to manage an order
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildButton(context, const Color(0xFF8B5CF6),
            order.status == 'revision' ? 'Open chat to deliver again' : 'Open chat to deliver',
            () => openOrderChat(context, order)),
          TextButton(
            onPressed: () => _confirmCancellation(context, order),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626), minimumSize: const Size(0, 36)),
            child: const Text('Request cancellation', style: TextStyle(fontSize: 13)),
          ),
        ],
      );
    } else if (order.status == 'delivered') {
      return _buildLabel(const Color(0xFFD97706), const Color(0xFFFEF3C7), const Color(0xFFFDE68A), 'Waiting for Client Approval');
    } else if (order.status == 'completed') {
      if (order.hasReview && !order.isReviewPublic) {
        return _buildButton(context, const Color(0xFF8B5CF6), 'Rate the buyer in chat', () => openOrderChat(context, order));
      }
      return _buildLabel(const Color(0xFF059669), const Color(0xFFD1FAE5), const Color(0xFFA7F3D0), 'Order Completed');
    } else if (order.status == 'cancelled') {
      return _buildLabel(const Color(0xFFDC2626), const Color(0xFFFEF2F2), const Color(0xFFFECACA), 'Order Cancelled');
    }
    return const SizedBox();
  }

  void _confirmCancellation(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Request Cancellation?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
        content: const Text('Are you sure you want to request cancellation for this order? The buyer will need to approve it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No, Go Back'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': 'cancel_requested_by_freelancer'});
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('Yes, Cancel Order'),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(Color textColor, Color bgColor, Color borderColor, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildButton(BuildContext context, Color color, String text, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: Text(text, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
    );
  }


}

void _showWithdrawalModal(BuildContext context, double availableBalance, String uid, String displayName, String? email) {
  final amountCtrl = TextEditingController();
  final payoneerCtrl = TextEditingController();
  bool submitting = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (c) => FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (payoneerCtrl.text.isEmpty && snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          if (data['payoneerEmail'] != null) {
            payoneerCtrl.text = data['payoneerEmail'];
          }
        }

        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24, left: 24, right: 24,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Withdraw Funds', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Available Balance: \$${availableBalance.toStringAsFixed(2)}', style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  
                  // Warning Note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Note: Your ReskinDev account name and your Payoneer account name must be exactly the same. Otherwise, the withdrawal will be rejected.',
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.blue.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  TextField(
                    controller: payoneerCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Payoneer Email Address',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount to Withdraw (Min \$50)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: submitting ? null : () async {
                        final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                        final payoneerEmail = payoneerCtrl.text.trim();
                        
                        if (payoneerEmail.isEmpty || !payoneerEmail.contains('@')) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid Payoneer email')));
                          return;
                        }
                        if (amount < 50) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum withdrawal amount is \$50')));
                          return;
                        }
                        if (amount > availableBalance) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient funds available for withdrawal')));
                          return;
                        }

                        setState(() => submitting = true);
                        
                        try {
                          await FirebaseFirestore.instance.collection('withdrawals').add({
                            'freelancerId': uid,
                            'freelancerName': displayName,
                            'email': payoneerEmail,
                            'amount': amount,
                            'charge': 3.0,
                            'netAmount': amount - 3.0,
                            'status': 'pending',
                            'createdAt': FieldValue.serverTimestamp(),
                          }).timeout(const Duration(seconds: 10));
                          
                          // Use set with merge instead of update, in case user doc is missing
                          await FirebaseFirestore.instance.collection('users').doc(uid).set({
                            'payoneerEmail': payoneerEmail
                          }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal request submitted successfully!'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error submitting request. Please try again.'), backgroundColor: Colors.red));
                          }
                        } finally {
                          if (context.mounted) {
                            setState(() => submitting = false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                      child: submitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    ),
  );
}
