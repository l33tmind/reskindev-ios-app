import re

with open('lib/widgets/chat_bubble.dart', 'r') as f:
    content = f.read()

old_code = """          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration("""

new_code = """          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration("""

content = content.replace(old_code, new_code)
with open('lib/widgets/chat_bubble.dart', 'w') as f:
    f.write(content)

print("Added constraints to ChatBubble")
