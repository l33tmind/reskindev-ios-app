import 'package:confetti/confetti.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/chat_provider.dart' as chat;
import '../providers/settings_provider.dart';
import '../providers/page_provider.dart';
import '../theme.dart';
import '../services/notification_service.dart';
import 'package:shimmer/shimmer.dart';
import '../widgets/web_nav_bar.dart';
import '../widgets/live_timer.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  String _filterStatus = 'all';
  bool _checkedAutoCompletes = false;

  void _checkAutoCompletes(List<OrderModel> orders) async {
    final now = DateTime.now();
    for (var order in orders) {
      if (order.status == 'delivered' && order.deliveredAt != null) {
        if (now.difference(order.deliveredAt!).inDays >= 3) {
          final systemReview = {
            'userId': 'system',
            'userName': 'System (Auto-Completed)',
            'userImage': 'https://ui-avatars.com/api/?name=System',
            'rating': 5.0,
            'ratingCommunication': 5.0,
            'ratingQuality': 5.0,
            'ratingDescribed': 5.0,
            'comment': 'Order automatically completed after 3 days of delivery.',
            'createdAt': FieldValue.serverTimestamp(),
          };
          
          await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
            'hasReview': true,
            'isReviewPublic': true,
            'buyerReview': systemReview,
            'sellerReview': systemReview,
          });
          
          final gigRef = FirebaseFirestore.instance.collection('services').doc(order.gigId);
          await gigRef.collection('reviews').add({
            'orderId': order.id,
            ...systemReview
          });
          
          final reviewsSnap = await gigRef.collection('reviews').get();
          if (reviewsSnap.docs.isNotEmpty) {
            double totalRating = 0;
            for (var r in reviewsSnap.docs) {
              totalRating += (r.data()['rating'] as num?)?.toDouble() ?? 5.0;
            }
            final avgRating = totalRating / reviewsSnap.docs.length;
            await gigRef.update({
              'rating': avgRating,
              'reviewCount': reviewsSnap.docs.length,
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final pageProv = context.watch<PageProvider>();

    if (auth.user == null) {
      return _buildLoginPrompt(context, auth);
    }

    return Scaffold(
      backgroundColor: context.themeBackground,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where(Filter.or(Filter('userId', isEqualTo: auth.user!.uid), Filter('clientUid', isEqualTo: auth.user!.uid)))
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (snap.hasError) {
             return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.red)));
          }
          final allOrders = (snap.data?.docs ?? [])
              .map((d) => OrderModel.fromFirestore(d))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (!_checkedAutoCompletes && allOrders.isNotEmpty) {
            _checkedAutoCompletes = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkAutoCompletes(allOrders);
            });
          }

          if (kIsWeb) {
            return _buildWebLayout(context, auth, settings, pageProv, allOrders);
          }
          return _buildMobileLayout(context, auth, allOrders);
        },
      ),
    );
  }

  Widget _buildWebLayout(
    BuildContext context,
    ap.AuthProvider auth,
    SettingsProvider settings,
    PageProvider pageProv,
    List<OrderModel> allOrders,
  ) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Column(
      children: [
        WebNavBar(
          auth: auth,
          settings: settings,
          pageProv: pageProv,
          isDesktop: isDesktop,
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktop) _buildWebSidebar(allOrders),
              if (isDesktop) VerticalDivider(width: 1, color: context.themeBorder),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    if (!isDesktop)
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _FilterDelegate(
                          allOrders: allOrders,
                          currentFilter: _filterStatus,
                          onFilterChanged: (v) => setState(() => _filterStatus = v),
                        ),
                      ),
                    SliverPadding(
                      padding: EdgeInsets.all(24),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'My Orders',
                          style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: context.themeTextDark),
                        ),
                      ),
                    ),
                    if (allOrders.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: _buildWebStats(allOrders),
                        ),
                      ),
                    _buildOrdersList(allOrders, isWeb: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebSidebar(List<OrderModel> allOrders) {
    final tabs = [
      ('all', 'All Orders', allOrders.length, Icons.all_inbox_rounded),
      ('pending', 'Pending', allOrders.where((o) => o.status == 'pending').length, Icons.schedule_rounded),
      ('in_progress', 'In Progress', allOrders.where((o) => o.status == 'in_progress').length, Icons.sync_rounded),
      ('completed', 'Completed', allOrders.where((o) => o.status == 'completed').length, Icons.check_circle_rounded),
    ];

    return Container(
      width: 250,
      color: context.themeSurface,
      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filters', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: context.themeTextDark)),
          const SizedBox(height: 16),
          ...tabs.map((tab) {
            final isSelected = _filterStatus == tab.$1;
            return Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                selected: isSelected,
                selectedTileColor: AppTheme.primary.withValues(alpha: 0.1),
                leading: Icon(tab.$4, color: isSelected ? AppTheme.primary : context.themeTextLight),
                title: Text(tab.$2, style: GoogleFonts.inter(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? AppTheme.primary : context.themeTextDark)),
                trailing: Text('${tab.$3}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? AppTheme.primary : context.themeTextLight)),
                onTap: () => setState(() => _filterStatus = tab.$1),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWebStats(List<OrderModel> orders) {
    final pending = orders.where((o) => o.status == 'pending').length;
    final inProgress = orders.where((o) => o.status == 'in_progress').length;
    final completed = orders.where((o) => o.status == 'completed').length;
    
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Pending', value: '$pending', color: AppTheme.warning, bgColor: AppTheme.warning.withValues(alpha: 0.1), icon: Icons.schedule_rounded)),
        const SizedBox(width: 16),
        Expanded(child: _StatCard(label: 'In Progress', value: '$inProgress', color: AppTheme.info, bgColor: AppTheme.info.withValues(alpha: 0.1), icon: Icons.sync_rounded)),
        const SizedBox(width: 16),
        Expanded(child: _StatCard(label: 'Completed', value: '$completed', color: AppTheme.success, bgColor: AppTheme.success.withValues(alpha: 0.1), icon: Icons.check_circle_rounded)),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    ap.AuthProvider auth,
    List<OrderModel> allOrders,
  ) {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) setState(() {});
      },
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: context.themeSurface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 1,
            title: Text('My Orders', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: context.themeTextDark)),
            actions: [
              if (auth.isFreelancer)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextButton.icon(
                    onPressed: () => context.push('/seller'),
                    icon: Icon(Icons.dashboard_rounded, size: 16, color: AppTheme.primary),
                    label: Text('Seller Dashboard', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    style: TextButton.styleFrom(
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
            ],
          ),
          SliverMainAxisGroup(
            slivers: [
              if (allOrders.isNotEmpty)
                SliverToBoxAdapter(child: _buildMobileStats(allOrders)),
              if (allOrders.isNotEmpty)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _FilterDelegate(
                    allOrders: allOrders,
                    currentFilter: _filterStatus,
                    onFilterChanged: (v) => setState(() => _filterStatus = v),
                  ),
                ),
              _buildOrdersList(allOrders, isWeb: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStats(List<OrderModel> orders) {
    final pending = orders.where((o) => o.status == 'pending').length;
    final inProgress = orders.where((o) => o.status == 'in_progress').length;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'In Progress',
              value: '$inProgress',
              color: AppTheme.info,
              bgColor: AppTheme.info.withValues(alpha: 0.1),
              icon: Icons.sync_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'Pending',
              value: '$pending',
              color: AppTheme.warning,
              bgColor: AppTheme.warning.withValues(alpha: 0.1),
              icon: Icons.schedule_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<OrderModel> allOrders, {required bool isWeb}) {
    if (allOrders.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long_rounded, size: 48, color: AppTheme.primary),
              ),
              const SizedBox(height: 24),
              Text('No orders yet',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: context.themeTextDark),
              ),
              const SizedBox(height: 8),
              Text('Explore our services and start your project',
                style: GoogleFonts.inter(color: context.themeTextLight, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Browse Services'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filterStatus == 'all'
        ? allOrders
        : allOrders.where((o) => o.status == _filterStatus).toList();

    if (filtered.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.filter_alt_off_rounded, size: 48, color: context.themeBorder),
              const SizedBox(height: 16),
              Text('No $_filterStatus orders',
                style: GoogleFonts.inter(fontSize: 16, color: context.themeTextLight),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: isWeb ? 24 : 16, vertical: 8),
      sliver: isWeb 
        ? SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisExtent: 220,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _OrderCard(order: filtered[index]),
              childCount: filtered.length,
            ),
          )
        : SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OrderCard(order: filtered[index]),
                );
              },
              childCount: filtered.length,
            ),
          ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context, ap.AuthProvider auth) {
    return Scaffold(
      backgroundColor: context.themeBackground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Premium Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: context.themeSurface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: context.themeTextDark.withValues(alpha: 0.05),
                        blurRadius: 40,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: AppTheme.heroGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          size: 30, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Track Your Orders',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: context.themeTextDark,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please sign in with your Google account to view your purchase history and order status.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      color: context.themeTextLight,
                      height: 1.6,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 48),

                // Google Sign In Button
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: () => context.push('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.login_rounded, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Sign In / Register',
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ],
                    ),
                    ),
                  ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    if (GoRouter.of(context).canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                  child: Text(
                    'Go Back',
                    style: GoogleFonts.inter(
                        color: context.themeTextLight,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.themeBorder),
        boxShadow: [
          BoxShadow(color: context.isDarkMode ? Colors.transparent : Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.themeTextLight),
              ),
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: context.themeTextDark),
          ),
        ],
      ),
    );
  }
}

class _FilterDelegate extends SliverPersistentHeaderDelegate {
  final List<OrderModel> allOrders;
  final String currentFilter;
  final ValueChanged<String> onFilterChanged;

  _FilterDelegate({
    required this.allOrders,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  double get minExtent => 64;
  @override
  double get maxExtent => 64;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final tabs = [
      ('all', 'All', allOrders.length),
      ('pending', 'Pending', allOrders.where((o) => o.status == 'pending').length),
      ('in_progress', 'Progress', allOrders.where((o) => o.status == 'in_progress').length),
      ('completed', 'Done', allOrders.where((o) => o.status == 'completed').length),
    ];

    return Container(
      color: context.themeBackground,
      alignment: Alignment.centerLeft,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = currentFilter == tab.$1;
          
          return GestureDetector(
            onTap: () => onFilterChanged(tab.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : context.themeSurface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected ? Colors.transparent : context.themeBorder,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    tab.$2,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : context.themeTextDark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.2) : context.themeBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${tab.$3}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : context.themeTextLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(_FilterDelegate old) => 
      old.allOrders != allOrders || old.currentFilter != currentFilter;
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  Color _getStatusColor(BuildContext context, String status) {
    switch (status) {
      case 'pending': return AppTheme.warning;
      case 'in_progress': return AppTheme.info;
      case 'completed': return AppTheme.success;
      case 'cancelled': return AppTheme.error;
      default: return context.themeTextLight;
    }
  }

  String _formatStatus(String status) {
    return status.split('_').map((s) => s[0].toUpperCase() + s.substring(1)).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context, order.status);
    final date = order.createdAt;
    final formattedDate = '${date.day}/${date.month}/${date.year}';

    return Container(
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.themeBorder),
        boxShadow: [
          BoxShadow(color: context.isDarkMode ? Colors.transparent : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    order.status == 'completed' ? Icons.check_circle_rounded :
                    order.status == 'in_progress' ? Icons.sync_rounded :
                    Icons.schedule_rounded,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.gigTitle,
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: context.themeTextDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text('Package: ${order.packageName}',
                            style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight),
                          ),
                          Container(width: 4, height: 4, decoration: BoxDecoration(color: AppTheme.textMuted, shape: BoxShape.circle)),
                          Text(formattedDate,
                            style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight),
                          ),
                        ],
                      ),
                      if (order.status == 'in_progress' || order.status == 'requirements') ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 14, color: Colors.orange),
                            const SizedBox(width: 4),
                            LiveTimer(startTime: order.startedAt ?? order.createdAt, deliveryDays: order.deliveryDays),
                          ],
                        )
                      ],
                    ],
                  ),
                ),
                Text(
                  '\$${order.price.toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary),
                ),
              ],
            ),
          ),
          
          Divider(height: 1),

          // Action / Status Area
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatStatus(order.status),
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showOrderDetails(context),
                  icon: const Icon(Icons.info_outline_rounded, size: 16),
                  label: const Text('Details'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.themeTextDark,
                    textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OrderDetailsSheet(order: order),
    );
  }
}

  void _showRevisionModal(BuildContext context, OrderModel order) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: context.themeCard,
        title: Text('Request Revision', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What needs to be changed?', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 4,
              style: TextStyle(color: context.themeTextDark),
              decoration: const InputDecoration(hintText: 'Please describe the revisions needed...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (noteCtrl.text.trim().isEmpty) return;
              Navigator.pop(c);
              await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                'status': 'revision',
                'revisionNote': noteCtrl.text.trim(),
              });
              await NotificationService.sendAndSaveNotification(
                userId: order.authorId,
                title: 'Revision Requested',
                body: 'The buyer requested a revision for: ${order.gigTitle}',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revision Requested!')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Submit Request'),
          ),
        ],
      ),
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

class _OrderDetailsSheet extends StatelessWidget {
  final OrderModel order;
  const _OrderDetailsSheet({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: context.themeSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: context.themeBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Order Details',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: context.themeTextDark),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                children: [
                  _buildTimeline(context),
                  const Divider(height: 32),
                  _buildDetailRow(context, 'Gig', order.gigTitle),
                  const Divider(height: 32),
                  _buildDetailRow(context, 'Package', order.packageName),
                  const Divider(height: 32),
                  _buildDetailRow(context, 'Price', '\$${order.price.toStringAsFixed(2)}'),
                  const Divider(height: 32),
                  _buildDetailRow(context, 'Project Details', order.projectDetails.isEmpty ? 'None provided' : order.projectDetails),
                  if (order.status == 'cancel_requested_by_freelancer') ...[
                    const Divider(height: 32),
                    Text('The seller requested to cancel this order.', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: ElevatedButton(
                      onPressed: () => FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': 'cancelled'}),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('Accept Cancellation'),
                    )),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: OutlinedButton(
                      onPressed: () => FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': 'in_progress'}),
                      child: const Text('Decline'),
                    )),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: TextButton(
                      onPressed: () => FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': 'disputed'}),
                      child: const Text('Involve Admin', style: TextStyle(color: Colors.grey)),
                    )),
                  ],
                  if (order.status == 'cancel_requested_by_buyer') ...[
                    const Divider(height: 32),
                    Text('Waiting for seller to accept cancellation.', style: GoogleFonts.inter(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ],
                  if (order.status == 'disputed') ...[
                    const Divider(height: 32),
                    Text('Order is currently in dispute. An admin will review it soon.', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                  if (order.status == 'in_progress' || order.status == 'requirements') ...[
                    const Divider(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': 'cancel_requested_by_buyer'}),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                        child: const Text('Request Cancellation'),
                      ),
                    ),
                  ],
                  if (order.status == 'delivered') ...[
                    const Divider(height: 32),
                    _buildDetailRow(context, 'Delivery Note', order.deliveryNote.isEmpty ? 'No note provided' : order.deliveryNote),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx); // close details modal
                          showDialog(
                            context: context, // use main context
                            barrierDismissible: false,
                            builder: (c) => RatingDialog(order: order),
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1BCA75), foregroundColor: Colors.white),
                        child: const Text('Approve & Accept Delivery'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showRevisionModal(context, order);
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                        child: const Text('Request Revision'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/chat/new', extra: {
                          'targetUserId': order.authorId,
                          'targetUserName': 'Freelancer',
                          'targetUserAvatar': '',
                          'orderId': order.id,
                        });
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Message Seller'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                        foregroundColor: AppTheme.primary,
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showSupportModal(context, order, order.clientUid);
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                      child: const Text('Report Issue / Contact Support'),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


    Widget _buildTimeline(BuildContext context) {
    if (order.status == 'cancelled') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel, color: AppTheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'This order was cancelled.',
                style: GoogleFonts.inter(color: AppTheme.error, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    final s = order.status;
    final isPayment = true; // Always at least payment
    final isRequirements = s == 'requirements' || s == 'in_progress' || s == 'delivered' || s == 'completed';
    final isProcessing = s == 'in_progress' || s == 'delivered' || s == 'completed';
    final isDelivered = s == 'delivered' || s == 'completed';
    final isCompleted = s == 'completed';

    Widget _buildStep(String title, bool isActive, bool isLast, bool isFirst, bool isNextActive) {
      return Expanded(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 2,
                    color: isFirst ? Colors.transparent : (isActive ? AppTheme.primary : context.themeBorder),
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primary : context.themeSurface,
                    border: Border.all(color: isActive ? AppTheme.primary : context.themeBorder, width: 2),
                    shape: BoxShape.circle,
                  ),
                  child: isActive 
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: isLast ? Colors.transparent : (isNextActive ? AppTheme.primary : context.themeBorder),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? context.themeTextDark : context.themeTextLight,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStep('PAYMENT', isPayment, false, true, isRequirements),
          _buildStep('REQUIREMENTS', isRequirements, false, false, isProcessing),
          _buildStep('PROCESSING', isProcessing, false, false, isDelivered),
          _buildStep('DELIVERED', isDelivered, false, false, isCompleted),
          _buildStep('COMPLETED', isCompleted, true, false, false),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.inter(fontSize: 15, color: context.themeTextDark)),
      ],
    );
  }


}

class RatingDialog extends StatefulWidget {
  final OrderModel order;
  const RatingDialog({super.key, required this.order});

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double comms = 5.0;
  double quality = 5.0;
  double described = 5.0;
  final publicCtrl = TextEditingController();
  final privateCtrl = TextEditingController();
  bool submitting = false;

  Widget _buildStarRow(String title, double value, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
          Row(
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => onChanged(index + 1.0),
                child: Icon(
                  index < value ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber,
                  size: 28,
                ),
              );
            }),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF1BCA75).withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.check_circle_rounded, color: Color(0xFF1BCA75), size: 48),
                    ),
                    const SizedBox(height: 16),
                    Text('Order Completed!', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Please rate your experience with this freelancer.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildStarRow('Communication Level', comms, (v) => setState(() => comms = v)),
              _buildStarRow('Quality of Work', quality, (v) => setState(() => quality = v)),
              _buildStarRow('Service as Described', described, (v) => setState(() => described = v)),
              const SizedBox(height: 16),
              TextField(
                controller: publicCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Public Review',
                  hintText: 'Share your experience with others...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: privateCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Private Feedback (Optional)',
                  hintText: 'Only admin can see this...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submitting ? null : () async {
                    setState(() => submitting = true);
                    final overall = (comms + quality + described) / 3.0;
                    
                    // 1. Update Order
                    await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({
                      'status': 'completed',
                      'hasReview': true,
                      'completedAt': FieldValue.serverTimestamp(),
                      'ratingCommunication': comms,
                      'ratingQuality': quality,
                      'ratingDescribed': described,
                      'overallRating': overall,
                      'publicReview': publicCtrl.text.trim(),
                      'privateFeedback': privateCtrl.text.trim(),
                    });
                    
                    // Trigger system message
                    try {
                      if (context.mounted) {
                        final chatProvider = context.read<chat.ChatProvider>();
                        await chatProvider.sendSystemMessage(
                          buyerId: widget.order.clientUid,
                          buyerName: widget.order.clientName,
                          sellerId: widget.order.authorId,
                          sellerName: widget.order.userName,
                          orderId: widget.order.id ?? '',
                          gigTitle: widget.order.gigTitle,
                          actionType: 'order_completed',
                          text: 'Order Completed! Buyer left a ${overall.toStringAsFixed(1)}-star review.',
                          metadata: {
                            'rating': overall,
                            'comment': publicCtrl.text.trim(),
                          },
                        );
                      }
                    } catch (e) {
                      print('System msg err: $e');
                    }

                    // 2. Add Review to Subcollection
                    final user = FirebaseAuth.instance.currentUser;
                    final gigRef = FirebaseFirestore.instance.collection('services').doc(widget.order.gigId);
                    await gigRef.collection('reviews').add({
                      'orderId': widget.order.id,
                      'userId': user?.uid ?? '',
                      'userName': user?.displayName ?? 'Client',
                      'userImage': user?.photoURL ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(user?.displayName ?? "Client")}',
                      'rating': overall,
                      'comment': publicCtrl.text.trim(),
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    // 3. Fetch all reviews and update Parent Gig
                    final reviewsSnap = await gigRef.collection('reviews').get();
                    if (reviewsSnap.docs.isNotEmpty) {
                      double totalRating = 0;
                      for (var r in reviewsSnap.docs) {
                        totalRating += (r.data()['rating'] as num?)?.toDouble() ?? 5.0;
                      }
                      final newAvg = double.parse((totalRating / reviewsSnap.docs.length).toStringAsFixed(1));
                      
                      await gigRef.update({
                        'reviewCount': reviewsSnap.docs.length,
                        'rating': newAvg,
                        'averageRating': newAvg,
                      });
                    }

                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1BCA75),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: submitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Review'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}


class ReviewSuccessDialog extends StatefulWidget {
  const ReviewSuccessDialog({super.key});
  @override
  State<ReviewSuccessDialog> createState() => _ReviewSuccessDialogState();
}

class _ReviewSuccessDialogState extends State<ReviewSuccessDialog> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
                const SizedBox(height: 16),
                Text('Review Submitted!',
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your review is hidden until the seller reviews your order.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Awesome!'),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -50,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.1,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            ),
          ),
        ],
      ),
    );
  }
}
