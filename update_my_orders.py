import os
filepath = 'lib/screens/my_orders_screen.dart'
with open(filepath, 'r') as f:
    content = f.read()

# Add _buildTimeline widget class or method. We will add a method to _OrderDetailsSheet

timeline_code = '''
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

    final isPlaced = true;
    final isInProgress = order.status == 'in_progress' || order.status == 'completed';
    final isCompleted = order.status == 'completed';

    Widget _buildStep(String title, bool isActive, bool isLast) {
      return Expanded(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 2,
                    color: isActive ? AppTheme.primary : context.themeBorder,
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
                    color: isLast ? Colors.transparent : (isCompleted && isActive ? AppTheme.primary : context.themeBorder),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? context.themeTextDark : context.themeTextLight,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          _buildStep('Placed', isPlaced, false),
          _buildStep('Working', isInProgress, false),
          _buildStep('Delivered', isCompleted, true),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {'''

content = content.replace('  Widget _buildDetailRow(BuildContext context, String label, String value) {', timeline_code)

old_list = '''            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(24),
                children: [
                  _buildDetailRow(context, 'Gig', order.gigTitle),'''

new_list = '''            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                children: [
                  _buildTimeline(context),
                  const Divider(height: 32),
                  _buildDetailRow(context, 'Gig', order.gigTitle),'''

content = content.replace(old_list, new_list)

with open(filepath, 'w') as f:
    f.write(content)
