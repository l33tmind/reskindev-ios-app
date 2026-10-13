import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';
import '../models/order_model.dart';
import 'admin_orders_view.dart';
import 'admin_users_view.dart';

/// What needs the admin now, then how the business is doing. Every number is live and tappable.
class AdminOverviewView extends StatelessWidget {
  /// Opens a tab of the dashboard: 'orders:<filter>', 'users', 'gigs', 'tickets', 'verifications'
  final void Function(String target)? onOpen;
  const AdminOverviewView({super.key, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    final db = FirebaseFirestore.instance;
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('orders').snapshots(),
      builder: (context, orderSnap) => StreamBuilder<QuerySnapshot>(
        stream: db.collection('users').snapshots(),
        builder: (context, userSnap) => StreamBuilder<QuerySnapshot>(
          stream: db.collection('services').where('status', isEqualTo: 'pending').snapshots(),
          builder: (context, gigSnap) => StreamBuilder<QuerySnapshot>(
            stream: db.collection('support_tickets').snapshots(),
            builder: (context, ticketSnap) => StreamBuilder<QuerySnapshot>(
            stream: db.collection('verifications').where('status', isEqualTo: 'pending').snapshots(),
            builder: (context, verificationSnap) {
              final error = orderSnap.error ?? userSnap.error;
              if (error != null) return AdminErrorBox(error: error);
              if (!orderSnap.hasData || !userSnap.hasData) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              }
              final orders = orderSnap.data!.docs.map(OrderModel.fromFirestore).toList();
              final users = userSnap.data!.docs.map(AdminUser.fromDoc).toList();
              int count(bool Function(OrderModel) t) => orders.where(t).length;

              final toVerify = count((o) => o.status == 'pending_payment' || o.status == 'pending');
              final problems = count((o) => o.status == 'disputed' || o.status.startsWith('cancel_requested'));
              final delivered = count((o) => o.status == 'delivered');
              final active = count((o) => const ['requirements', 'processing', 'in_progress', 'revision'].contains(o.status));
              final pendingGigs = gigSnap.data?.docs.length ?? 0;
              final pendingVerifications = verificationSnap.data?.docs.length ?? 0;
              final openTickets = (ticketSnap.data?.docs ?? [])
                  .where((d) => ((d.data() as Map<String, dynamic>)['status'] ?? 'open') == 'open').length;

              final completed = orders.where((o) => o.status == 'completed').toList();
              final revenue = completed.fold<double>(0, (s, o) => s + o.price);
              final now = DateTime.now();
              final thisMonth = completed
                  .where((o) => (o.completedAt ?? o.createdAt).year == now.year && (o.completedAt ?? o.createdAt).month == now.month)
                  .fold<double>(0, (s, o) => s + o.price);
              final sellers = users.where((u) => u.role == 'freelancer' && !u.isGuest).length;
              final buyers = users.where((u) => !u.isSeller && !u.isGuest).length;
              final guests = users.where((u) => u.isGuest).length;
              final newThisWeek = users.where((u) => u.joined != null && now.difference(u.joined!).inDays < 7).length;

              final todo = [
                _Todo('Orders to verify', toVerify, Icons.payments_outlined, Colors.orange, 'orders:To verify'),
                _Todo('Problems / disputes', problems, Icons.report_gmailerrorred_rounded, AppTheme.error, 'orders:Problems'),
                _Todo('Gigs to approve', pendingGigs, Icons.work_outline_rounded, Colors.purple, 'gigs'),
                _Todo('Verifications to review', pendingVerifications, Icons.verified_user_outlined, const Color(0xFF1D9BF0), 'verifications'),
                _Todo('Open support tickets', openTickets, Icons.support_agent_rounded, AppTheme.info, 'tickets'),
              ].where((t) => t.count > 0).toList();

              return ListView(
                padding: EdgeInsets.all(isMobile ? 16 : 40),
                children: [
                  Text('Overview', style: GoogleFonts.outfit(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w800, color: context.themeTextDark)),
                  const SizedBox(height: 16),

                  // 1. Your to-do
                  _Heading(todo.isEmpty ? 'Nothing waiting for you' : 'Waiting for you'),
                  if (todo.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        const Icon(Icons.check_circle_rounded, color: AppTheme.success),
                        const SizedBox(width: 10),
                        Expanded(child: Text('All caught up. New orders and gigs will show up here and on your phone.',
                            style: GoogleFonts.inter(fontSize: 13.5, color: context.themeTextDark))),
                      ]),
                    ),
                  for (final t in todo) _TodoRow(todo: t, onTap: () => onOpen?.call(t.target)),

                  // 2. Orders right now
                  _Heading('Orders'),
                  Row(children: [
                    Expanded(child: _Metric(value: '$active', label: 'In progress', onTap: () => onOpen?.call('orders:Active'))),
                    const SizedBox(width: 10),
                    Expanded(child: _Metric(value: '$delivered', label: 'Delivered, waiting', onTap: () => onOpen?.call('orders:Delivered'))),
                    const SizedBox(width: 10),
                    Expanded(child: _Metric(value: '${completed.length}', label: 'Completed', onTap: () => onOpen?.call('orders:Completed'))),
                  ]),

                  // 3. Money
                  _Heading('Revenue (completed orders)'),
                  Row(children: [
                    Expanded(child: _Metric(value: adminMoney(revenue), label: 'All time', color: AppTheme.success)),
                    const SizedBox(width: 10),
                    Expanded(child: _Metric(value: adminMoney(thisMonth), label: 'This month', color: AppTheme.success)),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    height: 220,
                    padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
                    decoration: BoxDecoration(color: context.themeSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.themeBorder)),
                    child: _RevenueChart(completed: completed),
                  ),

                  // 4. People
                  _Heading('People'),
                  Row(children: [
                    Expanded(child: _Metric(value: '$buyers', label: 'Buyers', onTap: () => onOpen?.call('users'))),
                    const SizedBox(width: 10),
                    Expanded(child: _Metric(value: '$sellers', label: 'Sellers', onTap: () => onOpen?.call('users'))),
                    const SizedBox(width: 10),
                    Expanded(child: _Metric(value: '$guests', label: 'Guests', onTap: () => onOpen?.call('users'))),
                  ]),
                  const SizedBox(height: 8),
                  Text('$newThisWeek joined in the last 7 days · ${users.length} accounts in total',
                      style: GoogleFonts.inter(fontSize: 12.5, color: context.themeTextLight)),

                  // 5. Latest orders
                  _Heading('Latest orders'),
                  AdminCard(children: [
                    for (final o in (orders..sort((a, b) => b.createdAt.compareTo(a.createdAt))).take(5)) AdminOrderRow(order: o),
                  ]),
                  const SizedBox(height: 40),
                ],
              );
            },
          ),
          ),
        ),
      ),
    );
  }
}

class _Todo {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final String target;
  _Todo(this.label, this.count, this.icon, this.color, this.target);
}

class _TodoRow extends StatelessWidget {
  final _Todo todo;
  final VoidCallback onTap;
  const _TodoRow({required this.todo, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: todo.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Icon(todo.icon, color: todo.color),
                const SizedBox(width: 12),
                Expanded(child: Text(todo.label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: context.themeTextDark))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(12)),
                  child: Text('${todo.count}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: context.themeTextLight),
              ]),
            ),
          ),
        ),
      );
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  const _Metric({required this.value, required this.label, this.color, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(color: context.themeSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.themeBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, maxLines: 1, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: color ?? context.themeTextDark)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
          ]),
        ),
      );
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(text, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: context.themeTextDark)),
      );
}

/// Completed-order revenue for the last 6 months (it used to be a hard-coded sample chart)
class _RevenueChart extends StatelessWidget {
  final List<OrderModel> completed;
  const _RevenueChart({required this.completed});

  @override
  Widget build(BuildContext context) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    final months = List.generate(6, (i) => DateTime(now.year, now.month - 5 + i));
    final totals = [
      for (final m in months)
        completed.where((o) {
          final d = o.completedAt ?? o.createdAt;
          return d.year == m.year && d.month == m.month;
        }).fold<double>(0, (s, o) => s + o.price),
    ];
    final top = totals.fold<double>(0, (a, b) => b > a ? b : a);
    final maxY = top <= 0 ? 10.0 : top * 1.25;

    return BarChart(BarChartData(
      maxY: maxY,
      alignment: BarChartAlignment.spaceAround,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, _, rod, __) => BarTooltipItem(adminMoney(rod.toY), GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => FlLine(color: context.themeBorder, strokeWidth: 1, dashArray: [4, 4])),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          interval: maxY / 4,
          getTitlesWidget: (v, _) => Text(adminMoney(v.roundToDouble()), style: GoogleFonts.inter(fontSize: 10.5, color: context.themeTextLight)),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, _) => Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(names[months[v.toInt()].month - 1], style: GoogleFonts.inter(fontSize: 11, color: context.themeTextLight)),
          ),
        )),
      ),
      barGroups: [
        for (int i = 0; i < 6; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: totals[i], color: AppTheme.primary, width: 18, borderRadius: BorderRadius.circular(5)),
          ]),
      ],
    ));
  }
}
