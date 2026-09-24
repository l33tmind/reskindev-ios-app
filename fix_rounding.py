import re

# Fix GigProvider
with open('lib/providers/gig_provider.dart', 'r') as f:
    content = f.read()

content = content.replace("final avg = total / revSnap.docs.length;", "final avg = double.parse((total / revSnap.docs.length).toStringAsFixed(1));")

with open('lib/providers/gig_provider.dart', 'w') as f:
    f.write(content)

# Fix MyOrdersScreen
with open('lib/screens/my_orders_screen.dart', 'r') as f:
    content = f.read()

content = content.replace("final newAvg = totalRating / reviewsSnap.docs.length;", "final newAvg = double.parse((totalRating / reviewsSnap.docs.length).toStringAsFixed(1));")

with open('lib/screens/my_orders_screen.dart', 'w') as f:
    f.write(content)

print("Fixed rounding to 1 decimal place")
