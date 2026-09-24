import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    content = f.read()

# Revert my bad replace if it happened
content = content.replace("},\n                        ),\n                      );\n                    },\n                  ),\n                ),", "},\n                      );\n                    },\n                  ),\n                ),")

# Do it properly by finding the exact builder end
# The ListView.builder starts at line 388 and ends at line 498
# Let's just find "return bubble;\n                        }," and replace it
content = content.replace("return bubble;\n                        },\n                      );", "return bubble;\n                        },\n                        ),\n                      );")

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(content)

