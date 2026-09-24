import re

with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    c = f.read()

# Fix space bug in tags
old_tag_logic = """                  onChanged: (val) {
                    if (val.endsWith(' ') || val.endsWith(',')) {
                      final t = val.replaceAll(',', '').trim().toLowerCase();
                      if (t.isNotEmpty && !_tags.contains(t) && _tags.length < 5) {
                        setState(() {
                          _tags.add(t);
                        });
                        _tagInputCtrl.clear();
                      } else if (t.isEmpty || _tags.contains(t) || _tags.length >= 5) {
                        _tagInputCtrl.clear();
                      }
                    }
                  },"""

new_tag_logic = """                  onChanged: (val) {
                    if (val.endsWith(',')) {
                      final t = val.replaceAll(',', '').trim().toLowerCase();
                      if (t.isNotEmpty && !_tags.contains(t) && _tags.length < 5) {
                        setState(() {
                          _tags.add(t);
                        });
                        _tagInputCtrl.clear();
                      } else if (t.isEmpty || _tags.contains(t) || _tags.length >= 5) {
                        _tagInputCtrl.clear();
                      }
                    }
                  },"""

c = c.replace(old_tag_logic, new_tag_logic)

# Replace 'PENDING / PRIVATE' with 'SUBMIT FOR APPROVAL'
c = c.replace("'PENDING / PRIVATE'", "'SUBMIT FOR APPROVAL'")

# Replace 'Save Changes' with 'Save & Publish'
# Wait, if they select draft, 'Save & Publish' sounds weird. Maybe just 'Save Service'
c = c.replace("'Save Changes'", "'Save Service'")

with open('lib/screens/gig_editor_screen.dart', 'w') as f:
    f.write(c)

