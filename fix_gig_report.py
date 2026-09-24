import re

with open('lib/screens/gig_detail_screen.dart', 'r') as f:
    c = f.read()

old_actions = """                        ),
                      ),
                    ],
                  ),"""

new_actions = """                        ),
                      ),
                      if (FirebaseAuth.instance.currentUser != null)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: context.themeTextDark),
                          onSelected: (val) {
                            if (val == 'report') {
                              _showReportDialog(context, gig);
                            } else if (val == 'block') {
                              _showBlockDialog(context, gig);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'report', child: Text('Report Service')),
                            const PopupMenuItem(value: 'block', child: Text('Block Seller')),
                          ],
                        ),
                    ],
                  ),"""

c = c.replace(old_actions, new_actions)

old_end = """}
"""

new_end = """
void _showReportDialog(BuildContext context, GigModel gig) {
  showDialog(
    context: context,
    builder: (context) {
      final ctrl = TextEditingController();
      bool submitting = false;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Report Service'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(hintText: 'Why are you reporting this service?'),
              maxLines: 3,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: submitting ? null : () async {
                  if (ctrl.text.isEmpty) return;
                  setState(() => submitting = true);
                  await FirebaseFirestore.instance.collection('reports').add({
                    'type': 'gig',
                    'gigId': gig.id,
                    'sellerId': gig.authorId,
                    'reason': ctrl.text,
                    'reportedBy': FirebaseAuth.instance.currentUser?.uid,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted. We will review it shortly.')));
                  }
                },
                child: submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator()) : const Text('Submit'),
              ),
            ],
          );
        },
      );
    },
  );
}

void _showBlockDialog(BuildContext context, GigModel gig) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Block Seller'),
        content: const Text('Are you sure you want to block this seller? You will no longer see their services.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                await FirebaseFirestore.instance.collection('users').doc(uid).update({
                  'blockedUsers': FieldValue.arrayUnion([gig.authorId])
                });
              }
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seller blocked.')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Block'),
          ),
        ],
      );
    },
  );
}
}
"""
c = c.replace(old_end, new_end)

with open('lib/screens/gig_detail_screen.dart', 'w') as f:
    f.write(c)

