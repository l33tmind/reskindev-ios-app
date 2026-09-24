import 'dart:io';

void main() {
  // 1. Update Info.plist
  final plistFile = File('ios/Runner/Info.plist');
  if (plistFile.existsSync()) {
    var plistContent = plistFile.readAsStringSync();
    if (!plistContent.contains('UIBackgroundModes')) {
      final insertPosition = plistContent.indexOf('</dict>');
      if (insertPosition != -1) {
        final backgroundModes = '''
\t<key>UIBackgroundModes</key>
\t<array>
\t\t<string>fetch</string>
\t\t<string>remote-notification</string>
\t</array>
''';
        plistContent = plistContent.substring(0, insertPosition) + backgroundModes + plistContent.substring(insertPosition);
        plistFile.writeAsStringSync(plistContent);
        print('Updated Info.plist');
      }
    }
  }

  // 2. Update Entitlements
  final entitlements = [
    'ios/Runner/Runner.entitlements',
    'ios/Runner/RunnerRelease.entitlements',
    'ios/Runner/RunnerProfile.entitlements'
  ];

  for (var path in entitlements) {
    final file = File(path);
    if (file.existsSync()) {
      var content = file.readAsStringSync();
      if (!content.contains('aps-environment')) {
        final insertPosition = content.indexOf('</dict>');
        if (insertPosition != -1) {
          final apsEnv = '''
\t<key>aps-environment</key>
\t<string>development</string>
''';
          content = content.substring(0, insertPosition) + apsEnv + content.substring(insertPosition);
          file.writeAsStringSync(content);
          print('Updated \$path');
        }
      }
    } else if (path == 'ios/Runner/Runner.entitlements') {
      // Create if it doesn't exist
      file.writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>aps-environment</key>
\t<string>development</string>
</dict>
</plist>''');
      print('Created \$path');
    }
  }
  
  // 3. Update AppDelegate.swift for Firebase Messaging
  final appDelegate = File('ios/Runner/AppDelegate.swift');
  if (appDelegate.existsSync()) {
    var content = appDelegate.readAsStringSync();
    
    // Check if didRegisterForRemoteNotificationsWithDeviceToken is implemented
    if (!content.contains('didRegisterForRemoteNotificationsWithDeviceToken')) {
        final insertText = '''
  override func application(_ application: UIApplication,
  didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
''';
        // Add it before the last closing brace
        final lastBrace = content.lastIndexOf('}');
        if (lastBrace != -1) {
           content = content.substring(0, lastBrace) + insertText + content.substring(lastBrace);
           appDelegate.writeAsStringSync(content);
           print('Updated AppDelegate.swift');
        }
    }
  }
}
