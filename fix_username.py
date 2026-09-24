import re

path = "./lib/screens/profile_screen.dart"
with open(path, "r") as f:
    content = f.read()

# Replace the _onUsernameChanged logic entirely to do nothing
content = re.sub(
    r'void _onUsernameChanged\(String value\) \{.*?\n  \}',
    'void _onUsernameChanged(String value) {\n    // Username is now read-only to prevent crashes and sync issues.\n  }',
    content,
    flags=re.DOTALL
)

# Remove the username saving logic from _save()
content = re.sub(
    r'final newUsername = _usernameCtrl\.text\.trim\(\);\s*if \(newUsername != widget\.auth\.username && _canChangeUsername && newUsername\.isNotEmpty\) \{\s*final uid = widget\.auth\.user\?\.uid;\s*if \(uid != null\) \{\s*await FirebaseFirestore\.instance\.collection\(\'users\'\)\.doc\(uid\)\.update\(\{\s*\'usernameChanges\': FieldValue\.arrayUnion\(\[FieldValue\.serverTimestamp\(\)\]\)\s*\}\);\s*\}\s*\}',
    'final newUsername = widget.auth.username ?? ""; // Read-only',
    content,
    flags=re.DOTALL
)

# Update the widget.auth.updateProfile call in _save to remove username (or keep it if we want)
# It's better to just leave it as is, since newUsername won't change

# Find the UI part for username
ui_pattern = r'_buildField\(\s*controller: _usernameCtrl,\s*label: \'Username\',\s*icon: Icons\.alternate_email,\s*onChanged: _onUsernameChanged,\s*readOnly: !_canChangeUsername && _usernameCtrl\.text != widget\.auth\.username,\s*suffix: _isCheckingUsername.*?\),'

new_ui = """_buildField(
                  controller: _usernameCtrl, 
                  label: 'Username (Auto-Generated)', 
                  icon: Icons.alternate_email,
                  readOnly: true, // Made strictly read-only
                ),"""

content = re.sub(ui_pattern, new_ui, content, flags=re.DOTALL)

# Remove the error and change limit text for username
content = re.sub(r'if \(_usernameError != null\).*?Padding.*?Text.*?_usernameError\!.*?\},', '', content, flags=re.DOTALL)
content = re.sub(r'if \(!_canChangeUsername && _usernameError == null\).*?Padding.*?Text.*?2 username changes in 30 days\..*?\},', '', content, flags=re.DOTALL)

with open(path, "w") as f:
    f.write(content)
