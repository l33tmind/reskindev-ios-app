import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

# Extract the build method of _HomeScreenState
match = re.search(r'Widget build\(BuildContext context\) \{.*?(?=^  Widget _buildWebLayout)', content, re.DOTALL | re.MULTILINE)
if match:
    print(match.group(0))
else:
    # Just grab a large chunk around line 100
    print("Could not find build method cleanly.")
