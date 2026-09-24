import re

with open('lib/main.dart', 'r') as f:
    content = f.read()

old_block = """    // iOS Foreground Notifications
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, // Required to display a heads up notification
      badge: true,
      sound: true,
    );"""

new_block = """    // iOS Foreground Notifications
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: false, // Set to false because we use flutterLocalNotificationsPlugin to show it manually below
      badge: true,
      sound: true,
    );"""

if old_block in content:
    content = content.replace(old_block, new_block)
    with open('lib/main.dart', 'w') as f:
        f.write(content)
    print("Fixed Double Notification in main.dart")
else:
    print("Could not find block in main.dart")
