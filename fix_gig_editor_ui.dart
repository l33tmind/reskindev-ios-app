import 'dart:io';

void main() {
  final file = File('lib/screens/gig_editor_screen.dart');
  var content = file.readAsStringSync();
  
  // 1. Fix Youtube preview placeholder
  content = content.replaceAll(
    'color: const Color(0xFFF3F4F6)', 
    'color: context.themeCard'
  );
  
  content = content.replaceAll(
    'Icon(Icons.broken_image_outlined, size: 48, color: Color(0xFF9CA3AF))',
    'Icon(Icons.broken_image_outlined, size: 48, color: context.themeTextLight)'
  );

  // 2. Fix Youtube Preview overlay
  // The 'Colors.black.withOpacity(0.25)' is actually fine, but the label 'YouTube Preview' has red background. That's fine.

  // 3. Fix UGC checkbox box
  final oldUgcBox = '''
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                                borderRadius: BorderRadius.circular(8),
                              ),
''';
  final newUgcBox = '''
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.isDarkMode ? AppTheme.darkCard : const Color(0xFFF8F9FA),
                                border: Border.all(color: context.themeBorder),
                                borderRadius: BorderRadius.circular(8),
                              ),
''';
  if (content.contains(oldUgcBox)) {
    content = content.replaceFirst(oldUgcBox, newUgcBox);
  } else {
    print("Could not find old UGC box");
  }

  // 4. Improve TextFormField text colors in case they're forced to something bad
  // In `_buildTextField` (if it exists) or directly in `TextFormField`
  
  file.writeAsStringSync(content);
  print('Updated gig_editor_screen.dart colors');
}
