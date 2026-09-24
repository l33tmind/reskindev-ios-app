import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  var content = file.readAsStringSync();
  
  final oldInit = '''
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
''';

  final newInit = '''
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
''';

  if (content.contains('const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);')) {
    content = content.replaceAll(oldInit, newInit);
    file.writeAsStringSync(content);
    print('Fixed iOS initialization for flutter_local_notifications');
  } else {
    print('Could not find the exact initialization settings block.');
  }
}
