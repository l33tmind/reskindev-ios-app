with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

import_str = "import 'package:go_router/go_router.dart';"
if "import 'package:firebase_auth/firebase_auth.dart';" not in content:
    content = content.replace(import_str, import_str + "\nimport 'package:firebase_auth/firebase_auth.dart';\nimport 'package:cloud_firestore/cloud_firestore.dart';")
    with open('lib/screens/home_screen.dart', 'w') as f:
        f.write(content)
    print("Added imports to home_screen")
else:
    print("Imports already exist in home_screen")
