import re

with open('lib/screens/seller_dashboard_screen.dart', 'r') as f:
    c = f.read()

# Change 'requirements' check to include 'pending'
old_req = "} else if (order.status == 'requirements') {"
new_req = "} else if (order.status == 'requirements' || order.status == 'pending') {"
c = c.replace(old_req, new_req)

with open('lib/screens/seller_dashboard_screen.dart', 'w') as f:
    f.write(c)

