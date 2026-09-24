import re

path = "./lib/screens/profile_screen.dart"
with open(path, "r") as f:
    content = f.read()

# Replace the messy lines with a clean _buildField
content = re.sub(
    r'Column\(\s*crossAxisAlignment: CrossAxisAlignment\.start,\s*children: \[\s*_buildField\(\s*controller: _usernameCtrl,\s*label: \'Username \(Auto-Generated\)\',\s*icon: Icons\.alternate_email,\s*readOnly: true, // Made strictly read-only\s*\),, \s*\]',
    '''_buildField(
              controller: _usernameCtrl, 
              label: 'Username (Auto-Generated)', 
              icon: Icons.alternate_email,
              readOnly: true,
            ),''',
    content,
    flags=re.DOTALL
)

with open(path, "w") as f:
    f.write(content)
