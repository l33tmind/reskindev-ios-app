import re

with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    c = f.read()

# Remove import
c = c.replace("import 'package:html_editor_enhanced/html_editor.dart';\n", "")

# Remove _htmlCtrl declaration
c = c.replace("  final HtmlEditorController _htmlCtrl = HtmlEditorController();\n", "")

# Change _save
c = c.replace("'description': await _htmlCtrl.getText(),", "'description': _descCtrl.text,")

# Also fix the initial text to be plain text instead of HTML tags
c = c.replace("_descCtrl = TextEditingController(text: g?.description ?? '<h3>My Service</h3><p>Description goes here...</p>');", "_descCtrl = TextEditingController(text: g?.description ?? '');")

with open('lib/screens/gig_editor_screen.dart', 'w') as f:
    f.write(c)

