import re

with open('lib/providers/auth_provider.dart', 'r') as f:
    content = f.read()

old_save = """    if (!doc.exists) {
      updateData['createdAt'] = FieldValue.serverTimestamp();
    }"""

new_save = """    if (!doc.exists) {
      updateData['createdAt'] = FieldValue.serverTimestamp();
      updateData['role'] = 'freelancer';
    }"""
content = content.replace(old_save, new_save)

with open('lib/providers/auth_provider.dart', 'w') as f:
    f.write(content)

print("Added default freelancer role")
