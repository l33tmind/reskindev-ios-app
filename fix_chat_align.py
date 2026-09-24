import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    content = f.read()

old_list = """                      return ListView.builder(
                        reverse: true,
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount: messages.length + (messages.length >= _messageLimit ? 1 : 0),"""

new_list = """                      return Align(
                        alignment: Alignment.topCenter,
                        child: ListView.builder(
                          reverse: true,
                          shrinkWrap: true,
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          itemCount: messages.length + (messages.length >= _messageLimit ? 1 : 0),"""
content = content.replace(old_list, new_list)

# We also need to add closing parenthesis for Align
# It's at the end of the builder block:
old_end = """                        },
                      );
                    },
                  ),
                ),"""

new_end = """                        },
                        ),
                      );
                    },
                  ),
                ),"""
content = content.replace(old_end, new_end)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(content)

print("Fixed chat align")
