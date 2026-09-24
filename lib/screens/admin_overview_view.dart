import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';

class AdminOverviewView extends StatelessWidget {
  const AdminOverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard Overview',
              style: GoogleFonts.outfit(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w800, color: context.themeTextDark)),
          const SizedBox(height: 8),
          Text('Key metrics and analytics of your business.',
              style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
          const SizedBox(height: 32),
          
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').snapshots(),
            builder: (context, orderSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, userSnap) {
                  if (orderSnap.connectionState == ConnectionState.waiting || userSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                  }
                  
                  final orders = orderSnap.data?.docs ?? [];
                  final users = userSnap.data?.docs ?? [];
                  
                  double totalRevenue = 0;
                  int completedOrders = 0;
                  for (var doc in orders) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (data['status'] == 'completed') {
                      totalRevenue += (data['price'] as num?)?.toDouble() ?? 0;
                      completedOrders++;
                    }
                  }
                  
                  final activeUsers = users.where((u) {
                    final d = u.data() as Map<String, dynamic>;
                    return d['isBlocked'] != true;
                  }).length;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 900) {
                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                _MetricCard(
                                  width: (constraints.maxWidth - 16) / 2 > 150 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                                  title: 'Total Revenue', 
                                  value: '\$${totalRevenue.toStringAsFixed(0)}', 
                                  icon: Icons.attach_money, 
                                  color: Colors.green
                                ),
                                _MetricCard(
                                  width: (constraints.maxWidth - 16) / 2 > 150 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                                  title: 'Total Orders', 
                                  value: '${orders.length}', 
                                  icon: Icons.shopping_bag, 
                                  color: Colors.blue
                                ),
                                _MetricCard(
                                  width: (constraints.maxWidth - 16) / 2 > 150 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                                  title: 'Active Users', 
                                  value: '$activeUsers', 
                                  icon: Icons.people, 
                                  color: Colors.purple
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: _MetricCard(title: 'Total Revenue', value: '\$${totalRevenue.toStringAsFixed(0)}', icon: Icons.attach_money, color: Colors.green)),
                              const SizedBox(width: 24),
                              Expanded(child: _MetricCard(title: 'Total Orders', value: '${orders.length}', icon: Icons.shopping_bag, color: Colors.blue)),
                              const SizedBox(width: 24),
                              Expanded(child: _MetricCard(title: 'Active Users', value: '$activeUsers', icon: Icons.people, color: Colors.purple)),
                            ],
                          );
                        }
                      ),
                      const SizedBox(height: 48),
                      Text('Revenue Overview', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700, color: context.themeTextDark)),
                      const SizedBox(height: 24),
                      Container(
                        height: 300,
                        padding: EdgeInsets.only(left: 16, right: 24, top: 24, bottom: 40),
                        decoration: BoxDecoration(
                          color: context.themeSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.themeBorder),
                        ),
                        child: _buildRevenueChart(orders),
                      ),
                      const SizedBox(height: 60),
                    ],
                  );
                },
              );
            }
          ),
        ],
      ),
    );
  }
  
  Widget _buildRevenueChart(List<QueryDocumentSnapshot> orders) {
    // Generate simple chart data
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 5000,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
              return Text('M${value.toInt()}', style: const TextStyle(fontSize: 12));
            }),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) {
              return Text('\$${value.toInt()}', style: const TextStyle(fontSize: 12));
            }),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 1200, color: AppTheme.primary, width: 16, borderRadius: BorderRadius.circular(4))]),
          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 2500, color: AppTheme.primary, width: 16, borderRadius: BorderRadius.circular(4))]),
          BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 1800, color: AppTheme.primary, width: 16, borderRadius: BorderRadius.circular(4))]),
          BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 3200, color: AppTheme.primary, width: 16, borderRadius: BorderRadius.circular(4))]),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double? width;

  const _MetricCard({required this.title, required this.value, required this.icon, required this.color, this.width});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      width: width,
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.themeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: context.themeTextDark)),
          ),
          const SizedBox(height: 4),
          Text(title, style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
