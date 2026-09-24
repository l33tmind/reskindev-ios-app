with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    c = f.read()

import re

old_tags = """                    _buildSectionTitle('Search Tags'),
                    _buildTagsSection(context),"""
new_tags = """                    _buildSectionTitle('Search Tags / Keywords'),
                    _buildTagsSection(context),"""
c = c.replace(old_tags, new_tags)

old_input = """                  onSubmitted: (val) {
                    final t = val.trim().toLowerCase();
                    if (t.isNotEmpty && !_tags.contains(t) && _tags.length < 5) {
                      setState(() {
                        _tags.add(t);
                      });
                      _tagInputCtrl.clear();
                    }
                  },"""

new_input = """                  onChanged: (val) {
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
                  },
                  onSubmitted: (val) {
                    final t = val.replaceAll(',', '').trim().toLowerCase();
                    if (t.isNotEmpty && !_tags.contains(t) && _tags.length < 5) {
                      setState(() {
                        _tags.add(t);
                      });
                      _tagInputCtrl.clear();
                    }
                  },"""
c = c.replace(old_input, new_input)
with open('lib/screens/gig_editor_screen.dart', 'w') as f:
    f.write(c)
