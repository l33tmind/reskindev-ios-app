with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

# Add a closing brace for _HomeScreenState
content += "\n}\n"

# Add the missing classes
with open('fix_missing_classes.py', 'r') as f:
    # Just grab the missing_classes string definition
    fix_code = f.read()

import re
match = re.search(r'missing_classes = """(.*?)"""', fix_code, re.DOTALL)
missing_classes = match.group(1)
# Remove the "// Ensure the state class is closed properly\n}" from missing_classes since we just added it
missing_classes = missing_classes.replace("  // Ensure the state class is closed properly\n}\n", "")
content += missing_classes

# Add the new classes
with open('update_home.py', 'r') as f:
    update_code = f.read()

match = re.search(r'new_classes = """(.*?)"""', update_code, re.DOTALL)
new_classes = match.group(1)
content += new_classes

with open('lib/screens/home_screen.dart', 'w') as f:
    f.write(content)

print("Appended everything to home_screen.dart")
