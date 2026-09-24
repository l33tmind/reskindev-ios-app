import re

with open('lib/models/order_model.dart', 'r') as f:
    c = f.read()

# Add quantity field
old_prop = """    required this.packageName,
    required this.price,
    this.basePrice = 0,
    this.discountAmount = 0,
    this.deliveryDays = 3,"""

new_prop = """    required this.packageName,
    required this.price,
    this.basePrice = 0,
    this.discountAmount = 0,
    this.quantity = 1,
    this.deliveryDays = 3,"""

c = c.replace(old_prop, new_prop)

# Add to properties
old_def = """  final String packageName;
  final double price;
  final double basePrice;
  final double discountAmount;
  final int deliveryDays;"""

new_def = """  final String packageName;
  final double price;
  final double basePrice;
  final double discountAmount;
  final int quantity;
  final int deliveryDays;"""

c = c.replace(old_def, new_def)

# Add to fromFirestore
old_from = """      discountAmount: _parseDouble(d['discountAmount']) ?? 0,
      deliveryDays: _parseInt(d['deliveryDays']) ?? 3,"""

new_from = """      discountAmount: _parseDouble(d['discountAmount']) ?? 0,
      quantity: _parseInt(d['quantity']) ?? 1,
      deliveryDays: _parseInt(d['deliveryDays']) ?? 3,"""

c = c.replace(old_from, new_from)

# Add to toMap
old_to = """      'discountAmount': discountAmount,
      'deliveryDays': deliveryDays,"""

new_to = """      'discountAmount': discountAmount,
      'quantity': quantity,
      'deliveryDays': deliveryDays,"""

c = c.replace(old_to, new_to)

with open('lib/models/order_model.dart', 'w') as f:
    f.write(c)

