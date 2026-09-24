import re

with open('lib/screens/mobile_shell.dart', 'r') as f:
    content = f.read()

old_code = """              if (snapshot.hasData) {
                final chats = snapshot.data as List;
                for (var chat in chats) {
                  final Map unreads = chat.unreadCount;
                  if ((unreads[auth.user!.uid] ?? 0) > 0) {
                    unreadChatCount++;
                  }
                }
              }"""

new_code = """              if (snapshot.hasData && auth.isLoggedIn && auth.user != null) {
                final chats = snapshot.data as List;
                for (var chat in chats) {
                  final Map unreads = chat.unreadCount;
                  if ((unreads[auth.user!.uid] ?? 0) > 0) {
                    unreadChatCount++;
                  }
                }
              }"""
content = content.replace(old_code, new_code)

with open('lib/screens/mobile_shell.dart', 'w') as f:
    f.write(content)

print("Fixed MobileShell force unwrap crash")
