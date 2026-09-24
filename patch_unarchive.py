import re

with open('lib/providers/chat_provider.dart', 'r') as f:
    c = f.read()

c = c.replace("'updatedAt': FieldValue.serverTimestamp(),", "'updatedAt': FieldValue.serverTimestamp(),\n      'archivedBy': [],")

with open('lib/providers/chat_provider.dart', 'w') as f:
    f.write(c)
