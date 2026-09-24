import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';

class EarningsChart extends StatelessWidget {
  final List<QueryDocumentSnapshot> orders;
  const EarningsChart({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    // 1. Group by month (last 6 months)
    final now = DateTime.now();
    final List<double> monthlyEarnings = List.filled(6, 0.0);
    final List<String> monthLabels = [];

    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthStr = _getMonthStr(monthDate.month);
      monthLabels.add(monthStr);
    }

    double maxEarning = 0;

    for (var doc in orders) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'completed') {
                DateTime? parseD(dynamic val) {
          if (val == null) return null;
          if (val is Timestamp) return val.toDate();
          if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
          if (val is String) return DateTime.tryParse(val);
          return null;
        }
        final completedAt = parseD(data['completedAt']) ?? parseD(data['createdAt']) ?? DateTime.now();
        final monthsAgo = (now.year - completedAt.year) * 12 + now.month - completedAt.month;
        
        if (monthsAgo >= 0 && monthsAgo < 6) {
          final price = (data['price'] as num?)?.toDouble() ?? 0;
          final netEarning = price * 0.8; // Deduct 20% platform fee
          
          final index = 5 - monthsAgo;
          monthlyEarnings[index] += netEarning;
          if (monthlyEarnings[index] > maxEarning) {
            maxEarning = monthlyEarnings[index];
          }
        }
      }
    }

    if (maxEarning == 0) maxEarning = 100; // default scale
    final maxY = (maxEarning * 1.2).ceilToDouble(); // 20% headroom

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text('Net Earnings (Last 6 Months)', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem('\$${rod.toY.toStringAsFixed(0)}', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
                    }
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value >= 0 && value < 6) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(monthLabels[value.toInt()], style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text('\$${value.toInt()}', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey));
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(6, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: monthlyEarnings[i],
                        color: AppTheme.primary,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      )
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('20% platform fee deducted automatically', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
          )
        ],
      ),
    );
  }

  String _getMonthStr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
