import re

with open('lib/providers/auth_provider.dart', 'r') as f:
    content = f.read()

# Add _username
old_vars = """  String? _phone;
  String? _company;
  String? _address;
  String? _photoUrl;"""

new_vars = """  String? _phone;
  String? _company;
  String? _address;
  String? _photoUrl;
  String? _username;"""

if old_vars in content:
    content = content.replace(old_vars, new_vars)

# Add getters
old_getters = """  String? get phone => _phone;
  String? get company => _company;
  String? get address => _address;
  String? get photoUrl => _photoUrl;
  String get displayName => _currentUser?.displayName ?? 'Guest';"""

new_getters = """  String? get phone => _phone;
  String? get company => _company;
  String? get address => _address;
  String? get photoUrl => _photoUrl;
  String? get username => _username;
  String get displayName => _currentUser?.displayName ?? 'Guest';"""

if old_getters in content:
    content = content.replace(old_getters, new_getters)

# Clear in signout
old_clear = """        _phone = null;
        _company = null;
        _address = null;
        _photoUrl = null;
        _profileLoaded = false;"""

new_clear = """        _phone = null;
        _company = null;
        _address = null;
        _photoUrl = null;
        _username = null;
        _profileLoaded = false;"""

if old_clear in content:
    content = content.replace(old_clear, new_clear)

# Load in loadProfile
old_load = """        _phone = data['phone'] as String?;
        _company = data['company'] as String?;
        _address = data['address'] as String?;
        _photoUrl = data['photoUrl'] as String? ?? u.photoURL ?? '';"""

new_load = """        _phone = data['phone'] as String?;
        _company = data['company'] as String?;
        _address = data['address'] as String?;
        _photoUrl = data['photoUrl'] as String? ?? u.photoURL ?? '';
        _username = data['username'] as String?;"""

if old_load in content:
    content = content.replace(old_load, new_load)

# Add username to updateProfile signature
old_update = """  Future<void> updateProfile({
    String? name,
    String? phone,
    String? company,
    String? address,
  }) async {"""

new_update = """  Future<void> updateProfile({
    String? name,
    String? phone,
    String? company,
    String? address,
    String? username,
  }) async {"""

if old_update in content:
    content = content.replace(old_update, new_update)

# Add username to map
old_map = """    await _db.collection('users').doc(u.uid).set({
      'displayName': name ?? u.displayName,
      'phone': phone,
      'company': company,
      'address': address,
    }, SetOptions(merge: true));"""

new_map = """    Map<String, dynamic> updateData = {
      'displayName': name ?? u.displayName,
      'phone': phone,
      'company': company,
      'address': address,
    };
    if (username != null) updateData['username'] = username;
    await _db.collection('users').doc(u.uid).set(updateData, SetOptions(merge: true));"""

if old_map in content:
    content = content.replace(old_map, new_map)

# Set in updateProfile
old_set = """    _phone = phone;
    _company = company;
    _address = address;"""

new_set = """    _phone = phone;
    _company = company;
    _address = address;
    if (username != null) _username = username;"""

if old_set in content:
    content = content.replace(old_set, new_set)

with open('lib/providers/auth_provider.dart', 'w') as f:
    f.write(content)

print("Updated AuthProvider state for username")
