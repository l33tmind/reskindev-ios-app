import re

with open('lib/services/notification_service.dart', 'r') as f:
    c = f.read()

old_get_config = """    final doc = await FirebaseFirestore.instance.collection('admin_settings').doc('fcm_config').get();
    if (doc.exists && doc.data() != null) {
      _cachedServiceAccount = doc.data();
      return _cachedServiceAccount!;
    }"""

new_get_config = """    final doc = await FirebaseFirestore.instance.collection('admin_settings').doc('fcm_config').get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      if (data.containsKey('jsonString')) {
         // User pasted the whole JSON file into one string field
         _cachedServiceAccount = jsonDecode(data['jsonString'] as String);
      } else {
         // User created individual fields
         _cachedServiceAccount = data;
      }
      // Fix private key formatting if it got messed up (escaped newlines)
      if (_cachedServiceAccount!['private_key'] != null) {
        _cachedServiceAccount!['private_key'] = _cachedServiceAccount!['private_key'].replaceAll('\\\\n', '\\n');
      }
      return _cachedServiceAccount!;
    }"""

c = c.replace(old_get_config, new_get_config)

with open('lib/services/notification_service.dart', 'w') as f:
    f.write(c)
