import re

with open('lib/screens/seller_dashboard_screen.dart', 'r') as f:
    content = f.read()

old_deliver = """              await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                'status': 'delivered',
                'deliveryNote': noteCtrl.text.trim(),
              });"""

new_deliver = """              await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                'status': 'delivered',
                'deliveryNote': noteCtrl.text.trim(),
                'deliveredAt': FieldValue.serverTimestamp(),
              });"""
content = content.replace(old_deliver, new_deliver)

with open('lib/screens/seller_dashboard_screen.dart', 'w') as f:
    f.write(content)

with open('lib/models/order_model.dart', 'r') as f:
    content = f.read()

# Add deliveredAt to OrderModel
old_model = """  final DateTime? completedAt;
  final DateTime? startedAt;"""
new_model = """  final DateTime? completedAt;
  final DateTime? startedAt;
  final DateTime? deliveredAt;"""
content = content.replace(old_model, new_model)

old_constructor = """    this.completedAt,
    this.startedAt,"""
new_constructor = """    this.completedAt,
    this.startedAt,
    this.deliveredAt,"""
content = content.replace(old_constructor, new_constructor)

old_from = """      completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
      startedAt: (d['startedAt'] as Timestamp?)?.toDate(),"""
new_from = """      completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
      startedAt: (d['startedAt'] as Timestamp?)?.toDate(),
      deliveredAt: (d['deliveredAt'] as Timestamp?)?.toDate(),"""
content = content.replace(old_from, new_from)

old_to = """      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (startedAt != null) 'startedAt': Timestamp.fromDate(startedAt!),"""
new_to = """      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (startedAt != null) 'startedAt': Timestamp.fromDate(startedAt!),
      if (deliveredAt != null) 'deliveredAt': Timestamp.fromDate(deliveredAt!),"""
content = content.replace(old_to, new_to)

with open('lib/models/order_model.dart', 'w') as f:
    f.write(content)

print("Added deliveredAt timestamp logic")
