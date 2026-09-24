import re

with open('lib/screens/order_form_screen.dart', 'r') as f:
    content = f.read()

# Make Project Details optional
old_req = "validator: (v) => (v == null || v.trim().isEmpty) ? 'Please describe your project' : null,"
new_req = "// validator removed to make it optional"

content = content.replace(old_req, new_req)

with open('lib/screens/order_form_screen.dart', 'w') as f:
    f.write(content)

print("Made project details optional")
