import 'dart:io';

void main() {
  final file = File('ios/Runner/AppDelegate.swift');
  var content = file.readAsStringSync();
  
  if (!content.contains('import FirebaseMessaging')) {
    content = content.replaceFirst('import Flutter', 'import Flutter\nimport FirebaseMessaging');
    file.writeAsStringSync(content);
    print('Added import FirebaseMessaging');
  } else {
    print('Already imported.');
  }
}
