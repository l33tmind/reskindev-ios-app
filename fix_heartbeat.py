import re

with open('lib/providers/auth_provider.dart', 'r') as f:
    content = f.read()

old_vars = """  bool _profileLoaded = false;

  String get displayName => user?.displayName ?? '';"""

new_vars = """  bool _profileLoaded = false;
  Timer? _heartbeatTimer;

  String get displayName => user?.displayName ?? '';"""
content = content.replace(old_vars, new_vars)

old_init = """  AuthProvider() {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }"""

new_init = """  AuthProvider() {
    WidgetsBinding.instance.addObserver(this);
    _init();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_currentUser != null) {
        _setPresence(true);
      }
    });
  }"""
content = content.replace(old_init, new_init)

old_dispose = """  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }"""
new_dispose = """  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    super.dispose();
  }"""
content = content.replace(old_dispose, new_dispose)

with open('lib/providers/auth_provider.dart', 'w') as f:
    f.write(content)

print("Added Heartbeat Timer to AuthProvider")
