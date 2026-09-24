import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    content = f.read()

old_logic = """                          bool showDate = false;
                          if (index == 0) {
                            showDate = true;
                          } else {
                            final prevMsg = messages[index - 1];
                            if (msg.createdAt != null && prevMsg.createdAt != null) {
                              if (msg.createdAt!.day != prevMsg.createdAt!.day ||
                                  msg.createdAt!.month != prevMsg.createdAt!.month ||
                                  msg.createdAt!.year != prevMsg.createdAt!.year) {
                                showDate = true;
                              }
                            }
                          }"""

new_logic = """                          bool showDate = false;
                          if (index == messages.length - 1) {
                            showDate = true;
                          } else {
                            final olderMsg = messages[index + 1];
                            if (msg.createdAt != null && olderMsg.createdAt != null) {
                              if (msg.createdAt!.day != olderMsg.createdAt!.day ||
                                  msg.createdAt!.month != olderMsg.createdAt!.month ||
                                  msg.createdAt!.year != olderMsg.createdAt!.year) {
                                showDate = true;
                              }
                            }
                          }"""

content = content.replace(old_logic, new_logic)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(content)

print("Fixed date header logic")
