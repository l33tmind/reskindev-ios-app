import re

with open('lib/screens/inbox_screen.dart', 'r') as f:
    c = f.read()

c = c.replace('String _searchQuery = "";', 'String _searchQuery = "";\n  bool _showArchived = false;')

with open('lib/screens/inbox_screen.dart', 'w') as f:
    f.write(c)
