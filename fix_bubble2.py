with open('lib/widgets/chat_bubble.dart', 'r') as f:
    c = f.read()

c = c.replace("case 'requirements', 'requirements_submitted':", "case 'requirements':\n      case 'requirements_submitted':")
with open('lib/widgets/chat_bubble.dart', 'w') as f:
    f.write(c)
