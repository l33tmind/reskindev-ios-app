with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    c = f.read()

c = c.replace("bool _isSaving = false;", "bool _isSaving = false;\n  bool _agreedToTerms = false;")

with open('lib/screens/gig_editor_screen.dart', 'w') as f:
    f.write(c)

