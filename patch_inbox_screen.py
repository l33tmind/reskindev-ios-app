import re

with open('lib/screens/inbox_screen.dart', 'r') as f:
    c = f.read()

# Add _showArchived state
if "bool _showArchived = false;" not in c:
    c = c.replace("String _searchQuery = '';", "String _searchQuery = '';\n  bool _showArchived = false;")

# Replace StreamBuilder stream to include showArchived
old_stream = "stream: chatProvider.getInbox(currentUserId),"
new_stream = "stream: chatProvider.getInbox(currentUserId, showArchived: _showArchived),"
c = c.replace(old_stream, new_stream)

# Add Tabs UI before TextField
old_search_container = """          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: context.themeSurface,
            child: TextField("""

new_search_container = """          Container(
            color: context.themeSurface,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showArchived = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: !_showArchived ? AppTheme.primary : Colors.transparent, width: 2)),
                      ),
                      child: Center(child: Text('Active', style: GoogleFonts.inter(fontWeight: !_showArchived ? FontWeight.bold : FontWeight.normal, color: !_showArchived ? AppTheme.primary : context.themeTextLight))),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showArchived = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: _showArchived ? AppTheme.primary : Colors.transparent, width: 2)),
                      ),
                      child: Center(child: Text('Archived', style: GoogleFonts.inter(fontWeight: _showArchived ? FontWeight.bold : FontWeight.normal, color: _showArchived ? AppTheme.primary : context.themeTextLight))),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: context.themeSurface,
            child: TextField("""

c = c.replace(old_search_container, new_search_container)

# Add Dismissible to ListTile
old_listtile = """                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      onTap: () {"""

new_listtile = """                    return Dismissible(
                      key: Key(chat.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: _showArchived ? Colors.blue : Colors.orange,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: Icon(_showArchived ? Icons.unarchive : Icons.archive, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        chatProvider.toggleArchive(chat.id, currentUserId, !_showArchived);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_showArchived ? 'Chat Unarchived' : 'Chat Archived')));
                      },
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onTap: () {"""

c = c.replace(old_listtile, new_listtile)

# Close the Dismissible widget
old_trailing = """                      ),
                    );
                  },"""

new_trailing = """                      ),
                      ),
                    );
                  },"""

c = c.replace(old_trailing, new_trailing)

with open('lib/screens/inbox_screen.dart', 'w') as f:
    f.write(c)
