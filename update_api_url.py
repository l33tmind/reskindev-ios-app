import re

with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    content = f.read()

# Replace the URL
old_url = '"https://reskindev.com/upload.php"'
new_url = '"https://api.reskindev.com/upload.php"'

if old_url in content:
    content = content.replace(old_url, new_url)
    with open('lib/screens/gig_editor_screen.dart', 'w') as f:
        f.write(content)
    print("API URL updated successfully")
else:
    print("API URL not found")
