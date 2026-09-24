import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class QuickRepliesScreen extends StatefulWidget {
  const QuickRepliesScreen({super.key});

  @override
  State<QuickRepliesScreen> createState() => _QuickRepliesScreenState();
}

class _QuickRepliesScreenState extends State<QuickRepliesScreen> {
  final _textCtrl = TextEditingController();
  final _db = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  void _addReply() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _user == null) return;
    
    _textCtrl.clear();
    await _db.collection('users').doc(_user!.uid).update({
      'quickReplies': FieldValue.arrayUnion([text])
    }).catchError((e) {
      // If the field doesn't exist yet, arrayUnion might fail or work depending on rules, but set with merge is safer
      _db.collection('users').doc(_user!.uid).set({
        'quickReplies': FieldValue.arrayUnion([text])
      }, SetOptions(merge: true));
    });
  }

  void _removeReply(String text) async {
    if (_user == null) return;
    await _db.collection('users').doc(_user!.uid).update({
      'quickReplies': FieldValue.arrayRemove([text])
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const Scaffold(body: Center(child: Text('Not logged in')));
    
    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        title: Text('Quick Replies', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
        backgroundColor: context.themeBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: context.themeTextDark),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    style: GoogleFonts.inter(color: context.themeTextDark),
                    decoration: InputDecoration(
                      hintText: 'Add a new saved reply...',
                      hintStyle: GoogleFonts.inter(color: context.themeTextLight),
                      filled: true,
                      fillColor: context.themeSurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.themeBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.themeBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: _addReply,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _db.collection('users').doc(_user!.uid).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final replies = List<String>.from(data?['quickReplies'] ?? []);
                
                if (replies.isEmpty) {
                  return Center(
                    child: Text('No quick replies added yet.', style: GoogleFonts.inter(color: context.themeTextLight)),
                  );
                }
                
                return ListView.builder(
                  itemCount: replies.length,
                  itemBuilder: (context, index) {
                    final reply = replies[index];
                    return ListTile(
                      title: Text(reply, style: GoogleFonts.inter(color: context.themeTextDark)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _removeReply(reply),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
