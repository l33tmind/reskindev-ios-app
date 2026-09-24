import re

with open('lib/screens/seller_dashboard_screen.dart', 'r') as f:
    c = f.read()

# Add import
if "import '../widgets/countdown_timer.dart';" not in c:
    c = c.replace("import '../models/order_model.dart';", "import '../models/order_model.dart';\nimport '../widgets/countdown_timer.dart';")

# Add timer
old_code = """          if (order.projectDetails.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Details: ${order.projectDetails}', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 16),
          Row("""

new_code = """          if (order.projectDetails.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Details: ${order.projectDetails}', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (order.status == 'in_progress' && order.startedAt != null) ...[
            const SizedBox(height: 12),
            CountdownTimer(deadline: order.startedAt!.add(Duration(days: order.deliveryDays))),
          ],
          const SizedBox(height: 16),
          Row("""

c = c.replace(old_code, new_code)

with open('lib/screens/seller_dashboard_screen.dart', 'w') as f:
    f.write(c)

