import re

with open('lib/screens/seller_dashboard_screen.dart', 'r') as f:
    c = f.read()

# Remove the duplicate timer
c = c.replace("""          if (order.status == 'in_progress' && order.startedAt != null) ...[
            const SizedBox(height: 12),
            CountdownTimer(deadline: order.startedAt!.add(Duration(days: order.deliveryDays))),
          ],
          const SizedBox(height: 16),
          Row(""", """          const SizedBox(height: 16),
          Row(""")

with open('lib/screens/seller_dashboard_screen.dart', 'w') as f:
    f.write(c)

