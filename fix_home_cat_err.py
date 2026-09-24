import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

content = content.replace("cat.$2", "catIcon")
content = content.replace("cat.$1", "catName")

with open('lib/screens/home_screen.dart', 'w') as f:
    f.write(content)

print("Fixed cat errors")
