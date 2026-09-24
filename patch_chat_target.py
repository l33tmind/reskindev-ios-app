import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    c = f.read()

# Fix 1: Online status
old_stream1 = """                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.targetUserId)
                              .snapshots(),"""

new_stream1 = """                        if (widget.targetUserId.isEmpty) return const SizedBox.shrink();
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.targetUserId)
                              .snapshots(),"""
c = c.replace(old_stream1, new_stream1)

# Fix 2: Blocked status
old_stream2 = """          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.targetUserId)
                .snapshots(),"""

new_stream2 = """          if (widget.targetUserId.isEmpty) 
            const SizedBox.shrink()
          else
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.targetUserId)
                  .snapshots(),"""
c = c.replace(old_stream2, new_stream2)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(c)
