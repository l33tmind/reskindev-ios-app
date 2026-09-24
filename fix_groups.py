import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    content = f.read()

old_logic = """                          bool isFirst = true;
                          bool isLast = true;
                          
                          if (index > 0) {
                            final prevMsg = messages[index - 1];
                            if (prevMsg.senderId == msg.senderId) {
                              if (msg.createdAt != null && prevMsg.createdAt != null) {
                                if (msg.createdAt!.difference(prevMsg.createdAt!).inMinutes < 2) {
                                  isFirst = false;
                                }
                              } else {
                                isFirst = false;
                              }
                            }
                          }
                          
                          if (index < messages.length - 1) {
                            final nextMsg = messages[index + 1];
                            if (nextMsg.senderId == msg.senderId) {
                              if (msg.createdAt != null && nextMsg.createdAt != null) {
                                if (nextMsg.createdAt!.difference(msg.createdAt!).inMinutes < 2) {
                                  isLast = false;
                                }
                              } else {
                                isLast = false;
                              }
                            }
                          }"""

new_logic = """                          bool isFirst = true;
                          bool isLast = true;
                          
                          if (index < messages.length - 1) {
                            final olderMsg = messages[index + 1];
                            if (olderMsg.senderId == msg.senderId) {
                              if (msg.createdAt != null && olderMsg.createdAt != null) {
                                if (msg.createdAt!.difference(olderMsg.createdAt!).inMinutes.abs() < 2) {
                                  isFirst = false;
                                }
                              } else {
                                isFirst = false;
                              }
                            }
                          }
                          
                          if (index > 0) {
                            final newerMsg = messages[index - 1];
                            if (newerMsg.senderId == msg.senderId) {
                              if (msg.createdAt != null && newerMsg.createdAt != null) {
                                if (msg.createdAt!.difference(newerMsg.createdAt!).inMinutes.abs() < 2) {
                                  isLast = false;
                                }
                              } else {
                                isLast = false;
                              }
                            }
                          }"""

content = content.replace(old_logic, new_logic)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(content)

print("Fixed grouping logic")
