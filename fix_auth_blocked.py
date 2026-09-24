import re

with open('lib/providers/auth_provider.dart', 'r') as f:
    content = f.read()

# Add _blockedUsers list
if "List<String> _blockedUsers = [];" not in content:
    old_vars = """  String? _photoUrl;
  String? _role;"""
    new_vars = """  String? _photoUrl;
  String? _role;
  List<String> _blockedUsers = [];"""
    content = content.replace(old_vars, new_vars)
    
    old_getters = """  String get photoUrl => _photoUrl ?? '';
  String get role => _role ?? 'client';"""
    new_getters = """  String get photoUrl => _photoUrl ?? '';
  String get role => _role ?? 'client';
  List<String> get blockedUsers => _blockedUsers;"""
    content = content.replace(old_getters, new_getters)
    
    old_load = """        _displayName = data['name'] as String?;
        _photoUrl = data['photoUrl'] as String?;
        _role = data['role'] as String?;"""
    new_load = """        _displayName = data['name'] as String?;
        _photoUrl = data['photoUrl'] as String?;
        _role = data['role'] as String?;
        _blockedUsers = List<String>.from(data['blockedUsers'] ?? []);"""
    content = content.replace(old_load, new_load)
    
    with open('lib/providers/auth_provider.dart', 'w') as f:
        f.write(content)
    print("Added blockedUsers to AuthProvider")
else:
    print("Already added blockedUsers")
