import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    content = f.read()

# 1. Add Actions to AppBar
old_appbar_end = """                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column("""
new_appbar_end = """                      },
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'profile') {
                context.push('/seller-profile/${widget.targetUserId}');
              } else if (value == 'report') {
                _showReportDialog();
              } else if (value == 'block') {
                _showBlockDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'profile', child: Text('View Profile')),
              const PopupMenuItem(value: 'report', child: Text('Report User')),
              const PopupMenuItem(value: 'block', child: Text('Block User')),
            ],
          ),
        ],
      ),
      body: Column("""
if old_appbar_end in content:
    content = content.replace(old_appbar_end, new_appbar_end)

# 2. Add methods _showReportDialog and _showBlockDialog
old_methods = """  void _sendMessage() {"""
new_methods = """
  Future<void> _showReportDialog() async {
    String selectedReason = 'Spam';
    final reasons = ['Spam', 'Inappropriate Behavior', 'Scam/Fraud', 'Harassment', 'Other'];
    
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Why are you reporting this user?'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedReason,
                items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => selectedReason = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final currentUserId = context.read<AuthProvider>().user?.uid;
                if (currentUserId == null) return;
                
                await FirebaseFirestore.instance.collection('reports').add({
                  'reportedBy': currentUserId,
                  'reportedUser': widget.targetUserId,
                  'reason': selectedReason,
                  'createdAt': FieldValue.serverTimestamp(),
                  'status': 'pending',
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted successfully.')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBlockDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block User'),
        content: const Text('Are you sure you want to block this user? You will not be able to send or receive messages from them.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final currentUserId = context.read<AuthProvider>().user?.uid;
              if (currentUserId == null) return;
              
              await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
                'blockedUsers': FieldValue.arrayUnion([widget.targetUserId])
              });
              
              if (mounted) {
                // Refresh auth provider to get updated blockedUsers list immediately
                context.read<AuthProvider>().notifyListeners(); 
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked.')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {"""
if old_methods in content:
    content = content.replace(old_methods, new_methods)

# 3. Check blocked status before rendering input
old_input = """          _buildMessageInput(),
        ],
      ),
    );
  }"""
new_input = """          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).snapshots(),
            builder: (context, snapshot) {
              final auth = context.watch<AuthProvider>();
              final iBlockedThem = auth.blockedUsers.contains(widget.targetUserId);
              
              bool theyBlockedMe = false;
              if (snapshot.hasData && snapshot.data!.exists) {
                final targetData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                final targetBlocked = List<String>.from(targetData['blockedUsers'] ?? []);
                theyBlockedMe = targetBlocked.contains(auth.user?.uid);
              }
              
              if (iBlockedThem) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  color: context.themeSurface,
                  alignment: Alignment.center,
                  child: Text('You blocked this user. Unblock to send messages.', style: GoogleFonts.inter(color: Colors.red)),
                );
              }
              if (theyBlockedMe) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  color: context.themeSurface,
                  alignment: Alignment.center,
                  child: Text('You cannot reply to this conversation.', style: GoogleFonts.inter(color: Colors.grey)),
                );
              }
              
              return _buildMessageInput();
            },
          ),
        ],
      ),
    );
  }"""
if old_input in content:
    content = content.replace(old_input, new_input)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(content)
print("Added report/block to chat_screen")
