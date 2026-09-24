import re

with open('lib/providers/auth_provider.dart', 'r') as f:
    content = f.read()

old_save2 = """    if (!doc.exists || !(doc.data()?.containsKey('username') ?? false)) {
      final email = u.email ?? '';"""

new_save2 = """    if (doc.exists && !(doc.data()?.containsKey('role') ?? false)) {
      updateData['role'] = 'freelancer';
    }

    if (!doc.exists || !(doc.data()?.containsKey('username') ?? false)) {
      final email = u.email ?? '';"""
content = content.replace(old_save2, new_save2)

with open('lib/providers/auth_provider.dart', 'w') as f:
    f.write(content)

print("Fixed role assignment for existing users")
