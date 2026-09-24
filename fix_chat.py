import re

with open('lib/providers/chat_provider.dart', 'r') as f:
    content = f.read()

bad_string = "if (participants.contains(targetUserId) if (participants.contains(targetUserId) && participants.length == 2) {if (participants.contains(targetUserId) && participants.length == 2) { participants.length == 2 && doc.data()['orderId'] == null) {"
good_string = "if (participants.contains(targetUserId) && participants.length == 2 && doc.data()['orderId'] == null) {"

content = content.replace(bad_string, good_string)

with open('lib/providers/chat_provider.dart', 'w') as f:
    f.write(content)
