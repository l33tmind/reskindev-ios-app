import re

with open('lib/screens/order_form_screen.dart', 'r') as f:
    content = f.read()

content = content.replace("subtitle: 'Optional — helps us reach you faster',", "subtitle: 'Helps us reach you faster',")

with open('lib/screens/order_form_screen.dart', 'w') as f:
    f.write(content)

print("Fixed Contact Info subtitle")
