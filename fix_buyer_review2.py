import re

with open('lib/screens/my_orders_screen.dart', 'r') as f:
    content = f.read()

content = content.replace("'Order Completed! Buyer left a 5-star review.'", "'Order Completed! Buyer left a ${overall.toStringAsFixed(1)}-star review.'")

with open('lib/screens/my_orders_screen.dart', 'w') as f:
    f.write(content)

print("Injected actual rating into system message")
