import re

with open('pubspec.yaml', 'r') as f:
    c = f.read()

# Add dependency_overrides
override = """
dependency_overrides:
  path_provider_foundation: ^2.4.0
"""
c += override

with open('pubspec.yaml', 'w') as f:
    f.write(c)

