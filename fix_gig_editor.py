import re

with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    c = f.read()

# 1. Add imports
c = "import 'package:html_editor_enhanced/html_editor.dart';\n" + c

# 2. Add controller
c = c.replace("late TextEditingController _descCtrl;", "late TextEditingController _descCtrl;\n  final HtmlEditorController _htmlCtrl = HtmlEditorController();")

# 3. Replace TextFormField for description with HtmlEditor
old_desc_field = """                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 10,
                      style: GoogleFonts.inter(color: context.themeTextDark, fontSize: 13, height: 1.5),
                      decoration: InputDecoration(
                        hintText: 'Write a clear and simple description of what you offer...',
                        fillColor: context.themeSurface,
                        filled: true,
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                        ),
                      ),
                    ),"""

new_desc_field = """                    Container(
                      decoration: BoxDecoration(
                        color: context.themeSurface,
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: HtmlEditor(
                        controller: _htmlCtrl,
                        htmlEditorOptions: HtmlEditorOptions(
                          hint: 'Write a clear and simple description of what you offer...',
                          initialText: _descCtrl.text,
                        ),
                        htmlToolbarOptions: HtmlToolbarOptions(
                          toolbarPosition: ToolbarPosition.aboveEditor,
                          toolbarType: ToolbarType.nativeScrollable,
                          defaultToolbarButtons: [
                            const StyleButtons(),
                            const FontSettingButtons(fontSizeUnit: false),
                            const FontButtons(clearAll: false),
                            const ColorButtons(),
                            const ListButtons(listStyles: false),
                            const ParagraphButtons(textDirection: false, lineHeight: false, caseConverter: false),
                            const InsertButtons(video: false, audio: false, table: false, hr: false, otherFile: false),
                          ],
                        ),
                        otherOptions: const OtherOptions(height: 350),
                      ),
                    ),"""

c = c.replace(old_desc_field, new_desc_field)

# 4. Update save logic
old_save_desc = "'description': _descCtrl.text,"
new_save_desc = "'description': await _htmlCtrl.getText(),"
c = c.replace(old_save_desc, new_save_desc)

with open('lib/screens/gig_editor_screen.dart', 'w') as f:
    f.write(c)
