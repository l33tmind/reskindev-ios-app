import re

with open('lib/providers/chat_provider.dart', 'r') as f:
    content = f.read()

content = content.replace('.limitToLast(limit)', '.limit(limit)')

with open('lib/providers/chat_provider.dart', 'w') as f:
    f.write(content)

print("Fixed limit in ChatProvider")
