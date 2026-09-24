import re

with open('pubspec.yaml', 'r') as f:
    c = f.read()

c = c.replace("  path_provider_foundation: ^2.4.0", "  path_provider_foundation: 2.4.0")

with open('pubspec.yaml', 'w') as f:
    f.write(c)

