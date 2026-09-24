import 'dart:io';

void main() {
  final file = File('lib/screens/seller_dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  final oldCardTop = '''
                    Text(order.gigTitle, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                    Text('\${order.packageName} Package • \\\$\${order.price.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 12),
''';
  final newCardTop = '''
                    Text(order.gigTitle, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                    Text('\${order.packageName} Package • \\\$\${order.price.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.bold)),
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
''';
  if (content.contains(oldCardTop)) {
    content = content.replaceFirst(oldCardTop, newCardTop);
  } else {
    print("Could not find oldCardTop!");
  }

  // Add the countdown widget
  final timerWidget = '''
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
              Text('\${days}d \${hours}h \${minutes}m \${seconds}s', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 16)),
            ],
          ),
        );
      },
    );
  }
''';

  content = content.replaceFirst(
    'class _SellerOrdersView extends StatelessWidget {',
    timerWidget + '\nclass _SellerOrdersView extends StatelessWidget {'
  );

  file.writeAsStringSync(content);
  print('Done adding timer');
}
