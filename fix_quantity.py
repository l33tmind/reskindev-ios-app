import re

with open('lib/screens/order_form_screen.dart', 'r') as f:
    c = f.read()

c = c.replace("  final _addressCtrl = TextEditingController();\n", "  final _addressCtrl = TextEditingController();\n  int _quantity = 1;\n")

# And fix line 119 argument type 'double' to 'int' in deliveryDays?
# deliveryDays is int. package.deliveryDays is int. package.deliveryDays * _quantity should be int.
# But wait, why did it say double can't be assigned to int?
# Let's check `package.deliveryDays` type.
