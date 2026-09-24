with open('lib/screens/chat_screen.dart', 'r') as f:
    content = f.read()

# 1. Remove the image button
button_to_find = """            IconButton(
              icon: Icon(Icons.add_photo_alternate_outlined, color: context.themeTextLight),
              onPressed: _pickImage,
              tooltip: 'Send Image',
            ),
"""
if button_to_find in content:
    content = content.replace(button_to_find, "")
else:
    print("Could not find button")

# 2. Remove _pickImage method
import re
pick_image_pattern = r'Future<void> _pickImage\(\) async \{.*?\n  \}\n'
content = re.sub(pick_image_pattern, '', content, flags=re.DOTALL)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(content)
