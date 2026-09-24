import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    content = f.read()

old_logic = """                          bool isFirst = true;
                          bool isLast = true;
                          
                          if (index > 0) {
                            final prevMsg = messages[index - 1];
                            if (prevMsg.senderId == msg.senderId) {
                              if (msg.createdAt != null && prevMsg.createdAt != null) {
                                if (msg.createdAt!.difference(prevMsg.createdAt!).inMinutes.abs() < 2) {
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
                                if (nextMsg.createdAt!.difference(msg.createdAt!).inMinutes.abs() < 2) {
                                  isLast = false;
                                }
                              } else {
                                isLast = false;
                              }
                            }
                          }"""

# Wait, since I don't know the exact string (because it might not have .abs()), I will regex match or replace the whole block
