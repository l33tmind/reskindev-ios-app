import re

with open('lib/providers/auth_provider.dart', 'r') as f:
    content = f.read()

# 1. Add WidgetsBindingObserver
old_class = "class AuthProvider extends ChangeNotifier {"
new_class = "class AuthProvider extends ChangeNotifier with WidgetsBindingObserver {"
if old_class in content:
    content = content.replace(old_class, new_class)

# 2. Register observer in constructor
old_cons = """  AuthProvider() {
    // Listen to Firebase auth state — auto-refreshes all screens on sign-in/out
    _auth.authStateChanges().listen((firebaseUser) async {"""
new_cons = """  AuthProvider() {
    WidgetsBinding.instance.addObserver(this);
    // Listen to Firebase auth state — auto-refreshes all screens on sign-in/out
    _auth.authStateChanges().listen((firebaseUser) async {"""
if old_cons in content:
    content = content.replace(old_cons, new_cons)

# 3. Handle AppLifecycleState
lifecycle_method = """
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_currentUser != null) {
      if (state == AppLifecycleState.resumed) {
        _setPresence(true);
      } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
        _setPresence(false);
      }
    }
  }

  Future<void> _setPresence(bool isOnline) async {
    if (_currentUser == null) return;
    try {
      await _db.collection('users').doc(_currentUser!.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error setting presence: $e');
    }
  }
"""

if "void didChangeAppLifecycleState" not in content:
    # insert before the last closing brace
    idx = content.rfind("}")
    if idx != -1:
        content = content[:idx] + lifecycle_method + content[idx:]

# 4. Unregister observer in dispose (if dispose exists)
old_dispose = """  @override
  void dispose() {"""
new_dispose = """  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);"""
if old_dispose in content:
    content = content.replace(old_dispose, new_dispose)
else:
    dispose_method = """
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
"""
    idx = content.rfind("}")
    if idx != -1:
        content = content[:idx] + dispose_method + content[idx:]

# 5. Add initial setPresence to loadProfile
old_load = """        _role = data['role'] as String?;
      }
    } catch (e) {"""
new_load = """        _role = data['role'] as String?;
      }
      _setPresence(true);
    } catch (e) {"""
if old_load in content:
    content = content.replace(old_load, new_load)
    
# 6. Add setPresence false on signout
old_signout = """  Future<void> signOut() async {
    try {
      if (_currentUser != null) {"""
new_signout = """  Future<void> signOut() async {
    try {
      if (_currentUser != null) {
        await _setPresence(false);"""
if old_signout in content:
    content = content.replace(old_signout, new_signout)

with open('lib/providers/auth_provider.dart', 'w') as f:
    f.write(content)

print("Updated AuthProvider for Presence")
