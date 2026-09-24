import re

with open('lib/screens/profile_screen.dart', 'r') as f:
    c = f.read()

old_logic = """              else if (t.contains('term')) sub = 'Rules and guidelines';
              
              return _MenuTile("""

new_logic = """              else if (t.contains('term')) sub = 'Rules and guidelines';
              else if (t.contains('refund') || t.contains('cancel')) sub = 'Order cancellations and refunds';
              
              return _MenuTile("""

c = c.replace(old_logic, new_logic)

with open('lib/screens/profile_screen.dart', 'w') as f:
    f.write(c)
