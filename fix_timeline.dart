import 'dart:io';

void main() {
  final file = File('lib/screens/my_orders_screen.dart');
  var content = file.readAsStringSync();
  
  final startStr = 'Widget _buildTimeline(BuildContext context) {';
  final startIdx = content.indexOf(startStr);
  
  if (startIdx == -1) {
    print('Could not find _buildTimeline');
    return;
  }
  
  // Find where _buildDetailRow starts to know where _buildTimeline ends
  final endStr = 'Widget _buildDetailRow';
  final endIdx = content.indexOf(endStr, startIdx);
  
  if (endIdx == -1) {
    print('Could not find end of _buildTimeline');
    return;
  }
  
  final newTimeline = '''
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

  ''';
  
  content = content.substring(0, startIdx) + newTimeline + content.substring(endIdx);
  file.writeAsStringSync(content);
  print('Updated _buildTimeline');
}
