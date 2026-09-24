with open('lib/screens/order_form_screen.dart', 'r') as f:
    lines = f.readlines()

lines.insert(38, "  int _quantity = 1;\n")

with open('lib/screens/order_form_screen.dart', 'w') as f:
    f.writelines(lines)
