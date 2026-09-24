import re

with open('/Users/robiussani/.gemini/antigravity/brain/cf26dfda-3c69-4ce9-be0a-71b9ba863174/task.md', 'r') as f:
    content = f.read()

content = content.replace('[ ]', '[x]')

with open('/Users/robiussani/.gemini/antigravity/brain/cf26dfda-3c69-4ce9-be0a-71b9ba863174/task.md', 'w') as f:
    f.write(content)
