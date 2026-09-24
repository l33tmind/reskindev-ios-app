import re

with open('lib/providers/auth_provider.dart', 'r') as f:
    content = f.read()

# Add _blockedUsers list
if "List<String> _blockedUsers = [];" not in content:
    # Find _username = null;
    old_vars = """        _photoUrl = null;
        _username = null;"""
    new_vars = """        _photoUrl = null;
        _username = null;
        _blockedUsers.clear();"""
    content = content.replace(old_vars, new_vars)
    
    # Find _username var
    old_getters = """  String? _username;
  bool _profileLoaded = false;"""
    new_getters = """  String? _username;
  bool _profileLoaded = false;
  List<String> _blockedUsers = [];
  List<String> get blockedUsers => _blockedUsers;"""
    content = content.replace(old_getters, new_getters)
    
    # Load profile
    old_load = """        _address = data['address'] as String?;
        _username = data['username'] as String?;"""
    new_load = """        _address = data['address'] as String?;
        _username = data['username'] as String?;
        _blockedUsers = List<String>.from(data['blockedUsers'] ?? []);"""
    content = content.replace(old_load, new_load)
    
    with open('lib/providers/auth_provider.dart', 'w') as f:
        f.write(content)
    print("Added blockedUsers to AuthProvider")
else:
    print("Already added blockedUsers")
