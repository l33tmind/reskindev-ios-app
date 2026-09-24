import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

match = re.search(r'Widget _buildMobileLayout\(.*?\) \{.*?(?=^class _CategoryChipsList)', content, re.DOTALL | re.MULTILINE)
if match:
    print(match.group(0))
else:
    print("Could not find _buildMobileLayout method cleanly.")
