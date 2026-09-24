import re

with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    content = f.read()

old_space = """                    const SizedBox(height: 24),

                    const SizedBox(height: 48),
                    
                    const SizedBox(height: 48),

                                        _buildSectionTitle('Media'),"""

new_space = """                    const SizedBox(height: 24),
                    _buildSectionTitle('Media'),"""

if old_space in content:
    content = content.replace(old_space, new_space)
    with open('lib/screens/gig_editor_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed empty space")
else:
    print("Could not find empty space block")
