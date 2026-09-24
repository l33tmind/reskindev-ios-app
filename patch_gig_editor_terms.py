import re

with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    c = f.read()

# Add _agreedToTerms state
old_state = "bool _isSaving = false;\n  String _thumbnailUrl = '';"
new_state = "bool _isSaving = false;\n  bool _agreedToTerms = false;\n  String _thumbnailUrl = '';"
c = c.replace(old_state, new_state)

# Add checkbox in build
old_buttons = "                    const SizedBox(height: 48),\n                    Row("
new_buttons = """                    const SizedBox(height: 24),
                    CheckboxListTile(
                      value: _agreedToTerms,
                      onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                      title: Text(
                        'I agree to the Terms of Service and confirm this service contains no abusive, copyright-infringing, or objectionable content.',
                        style: GoogleFonts.inter(fontSize: 13, color: context.themeTextDark),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppTheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Row("""
c = c.replace(old_buttons, new_buttons)

# Disable save if not agreed
old_save_on_pressed = "onPressed: _isSaving ? null : _save,"
new_save_on_pressed = "onPressed: (!_agreedToTerms || _isSaving) ? null : _save,"
c = c.replace(old_save_on_pressed, new_save_on_pressed)

with open('lib/screens/gig_editor_screen.dart', 'w') as f:
    f.write(c)

