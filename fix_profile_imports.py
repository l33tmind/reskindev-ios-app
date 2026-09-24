import re

with open('lib/screens/profile_screen.dart', 'r') as f:
    content = f.read()

if "import 'dart:async';" not in content:
    content = "import 'dart:async';\n" + content

with open('lib/screens/profile_screen.dart', 'w') as f:
    f.write(content)
