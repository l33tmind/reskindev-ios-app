import 'dart:io';

void main() {
  final file = File('lib/screens/gig_editor_screen.dart');
  final lines = file.readAsLinesSync();
  
  final newContent = '''
                    const SizedBox(height: 48),
                    _buildSectionTitle('Gig Description'),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 10,
                      style: GoogleFonts.inter(color: context.themeTextDark, fontSize: 13, height: 1.5),
                      decoration: InputDecoration(
                        hintText: 'Write a clear and simple description of what you offer...',
                        fillColor: context.themeSurface,
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                        ),
                      ),
                    ),
''';
  
  lines.replaceRange(989, 1337, newContent.split('\n'));
  file.writeAsStringSync(lines.join('\n'));
  print('Replaced successfully');
}
