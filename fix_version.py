import re

with open('pubspec.yaml', 'r') as f:
    content = f.read()

content = content.replace('version: 19.0.0+19', 'version: 20.0.0+20')

with open('pubspec.yaml', 'w') as f:
    f.write(content)

print("Updated app version to 20")
