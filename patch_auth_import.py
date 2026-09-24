import re

with open('lib/widgets/order_chat_cards.dart', 'r') as f:
    c = f.read()

c = c.replace("import 'package:cloud_firestore/cloud_firestore.dart';", "import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'package:firebase_auth/firebase_auth.dart';")

with open('lib/widgets/order_chat_cards.dart', 'w') as f:
    f.write(c)
