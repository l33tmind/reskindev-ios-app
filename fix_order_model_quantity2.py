import re

with open('lib/models/order_model.dart', 'r') as f:
    c = f.read()

c = c.replace("  // Delivery\n  final int deliveryDays;\n", "  final int quantity;\n  // Delivery\n  final int deliveryDays;\n")

with open('lib/models/order_model.dart', 'w') as f:
    f.write(c)
