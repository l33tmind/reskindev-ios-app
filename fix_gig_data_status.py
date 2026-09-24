import re

with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    content = f.read()

old_gig_data = """      final Map<String, dynamic> gigData = {"""

new_gig_data = """      final user = FirebaseAuth.instance.currentUser;
      final isAdmin = user?.uid == 'md-robius-sany' || user?.email?.toLowerCase() == 'mdrobiussany1225@gmail.com';
      if (!isAdmin) {
        _status = 'pending';
      }

      final Map<String, dynamic> gigData = {"""

if old_gig_data in content:
    content = content.replace(old_gig_data, new_gig_data)
    with open('lib/screens/gig_editor_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed gigData status")
else:
    print("Could not find gigData!")
