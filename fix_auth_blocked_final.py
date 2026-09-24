import re

with open('lib/providers/auth_provider.dart', 'r') as f:
    content = f.read()

# Add to variables
if "List<String> _blockedUsers" not in content:
    content = content.replace("bool get isLoggedIn => _currentUser != null;", "bool get isLoggedIn => _currentUser != null;\n  List<String> _blockedUsers = [];\n  List<String> get blockedUsers => _blockedUsers;")

# Add to loadProfile
if "_blockedUsers = List<String>.from" not in content:
    content = content.replace("_role = data['role'] as String?;", "_role = data['role'] as String?;\n        _blockedUsers = List<String>.from(data['blockedUsers'] ?? []);")

# Add to signOut
if "_blockedUsers.clear();" not in content:
    content = content.replace("_role = null;", "_role = null;\n    _blockedUsers.clear();")

with open('lib/providers/auth_provider.dart', 'w') as f:
    f.write(content)

print("Fixed blockedUsers")
