import 'dart:io';

void main() {
  final file = File('lib/screens/gig_editor_screen.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceAll(
    'child: const Center(\n                                            child: Icon(Icons.broken_image_outlined, size: 48, color: context.themeTextLight),',
    'child: Center(\n                                            child: Icon(Icons.broken_image_outlined, size: 48, color: context.themeTextLight),'
  );
  
  file.writeAsStringSync(content);
  print('Removed const');
}
