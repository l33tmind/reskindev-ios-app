with open('lib/screens/chat_screen.dart', 'r') as f:
    c = f.read()

old_stream = """                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primary,
                              ),
                            );
                          }

                          final messages = snapshot.data ?? [];"""

new_stream = """                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primary,
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text('Error loading messages: ${snapshot.error}', style: TextStyle(color: Colors.red)));
                          }

                          final messages = snapshot.data ?? [];"""
c = c.replace(old_stream, new_stream)
with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(c)
