import re

with open('lib/models/order_model.dart', 'r') as f:
    c = f.read()

c = c.replace("  final double discountAmount;\n  final int deliveryDays;\n", "  final double discountAmount;\n  final int quantity;\n  final int deliveryDays;\n")

with open('lib/models/order_model.dart', 'w') as f:
    f.write(c)

