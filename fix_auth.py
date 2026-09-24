import re

path = "./lib/providers/auth_provider.dart"
with open(path, "r") as f:
    content = f.read()

# Add 'username': username to the set block
content = re.sub(
    r"'company': company,\s*'address': address,\s*\}, SetOptions\(merge: true\)\);",
    "'company': company,\n      'address': address,\n      if (username != null && username.isNotEmpty) 'username': username,\n    }, SetOptions(merge: true));",
    content
)

with open(path, "w") as f:
    f.write(content)
