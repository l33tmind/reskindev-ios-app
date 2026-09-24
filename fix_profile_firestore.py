import re

with open('lib/screens/profile_screen.dart', 'r') as f:
    content = f.read()

if "package:cloud_firestore/cloud_firestore.dart" not in content:
    content = "import 'package:cloud_firestore/cloud_firestore.dart';\n" + content

with open('lib/screens/profile_screen.dart', 'w') as f:
    f.write(content)
