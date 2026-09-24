import re

with open('lib/providers/chat_provider.dart', 'r') as f:
    content = f.read()

old_block = """    // Send push notification to other participants
    if (chatDoc.exists) {
      final participants = List<String>.from(chatDoc.data()!['participants'] ?? []);
      for (String p in participants) {
        if (p != currentUserId) {
          try {
            final userDoc = await _db.collection('users').doc(p).get();
            if (userDoc.exists) {
              final token = userDoc.data()?['fcmToken'] as String?;
              if (token != null && token.isNotEmpty) {"""

new_block = """    // Send push notification to other participants
    if (chatDoc.exists) {
      final participants = List<String>.from(chatDoc.data()!['participants'] ?? []);
      String? myDeviceToken;
      try {
        myDeviceToken = await FirebaseMessaging.instance.getToken();
      } catch (_) {}

      for (String p in participants) {
        if (p != currentUserId) {
          try {
            final userDoc = await _db.collection('users').doc(p).get();
            if (userDoc.exists) {
              final token = userDoc.data()?['fcmToken'] as String?;
              if (token != null && token.isNotEmpty && token != myDeviceToken) {"""

if old_block in content:
    content = content.replace(old_block, new_block)
    # add firebase_messaging import if not exists
    if "import 'package:firebase_messaging/firebase_messaging.dart';" not in content:
        content = "import 'package:firebase_messaging/firebase_messaging.dart';\n" + content
    with open('lib/providers/chat_provider.dart', 'w') as f:
        f.write(content)
    print("Fixed Chat Provider self-notification issue")
else:
    print("Could not find block in chat_provider.dart")
