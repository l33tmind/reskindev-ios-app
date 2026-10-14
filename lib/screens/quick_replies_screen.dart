import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

/// Ready-made replies for each side of a chat. Used until the person edits their own list.
class QuickReplyDefaults {
  static const seller = [
    "Hello! How can I help you?",
    "Thanks for your order! I'm starting now.",
    "Could you share a few more details?",
    "Let me check and get back to you shortly.",
    "I'll deliver this soon.",
    "Delivered! Please check and let me know.",
  ];

  static const buyer = [
    "Hi! Is this service available?",
    "Can you do a custom version for me?",
    "How long will delivery take?",
    "Here are the details for my order.",
    "Any update on my order?",
    "Thank you, looks great!",
  ];

  static List<String> forRole({required bool seller}) => seller ? QuickReplyDefaults.seller : buyer;

  /// Seller replies keep the old field name, so lists people already saved stay put
  static String field({required bool seller}) => seller ? 'quickReplies' : 'buyerQuickReplies';
}

/// Profile → Quick Replies: edit the replies offered behind ⚡ in chat, one list as seller and one as buyer.
class QuickRepliesScreen extends StatelessWidget {
  /// 'buyer' opens on the buyer tab (from a chat where you are the buyer)
  final String? initialRole;
  const QuickRepliesScreen({super.key, this.initialRole});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Not logged in')));

    return DefaultTabController(
      length: 2,
      initialIndex: initialRole == 'buyer' ? 1 : 0,
      child: Scaffold(
        backgroundColor: context.themeBackground,
        appBar: AppBar(
          title: Text('Quick Replies', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
          backgroundColor: context.themeBackground,
          elevation: 0,
          iconTheme: IconThemeData(color: context.themeTextDark),
          bottom: TabBar(
            labelColor: AppTheme.primary,
            unselectedLabelColor: context.themeTextLight,
            indicatorColor: AppTheme.primary,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
            tabs: const [Tab(text: 'As seller'), Tab(text: 'As buyer')],
          ),
        ),
        body: TabBarView(
          children: [
            _ReplyList(uid: user.uid, seller: true),
            _ReplyList(uid: user.uid, seller: false),
          ],
        ),
      ),
    );
  }
}

class _ReplyList extends StatefulWidget {
  final String uid;
  final bool seller;
  const _ReplyList({required this.uid, required this.seller});

  @override
  State<_ReplyList> createState() => _ReplyListState();
}

class _ReplyListState extends State<_ReplyList> {
  final _textCtrl = TextEditingController();

  DocumentReference get _doc => FirebaseFirestore.instance.collection('users').doc(widget.uid);
  String get _field => QuickReplyDefaults.field(seller: widget.seller);

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  /// The first edit saves the ready-made list, so removing a ready-made reply works too
  Future<void> _save(List<String> replies) => _doc.set({_field: replies}, SetOptions(merge: true));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _doc.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final hasOwn = data?.containsKey(_field) == true;
        final replies = hasOwn ? List<String>.from(data![_field] ?? []) : List<String>.from(QuickReplyDefaults.forRole(seller: widget.seller));

        void add() {
          final text = _textCtrl.text.trim();
          if (text.isEmpty || replies.contains(text)) return;
          _textCtrl.clear();
          _save([...replies, text]);
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => add(),
                      style: GoogleFonts.inter(color: context.themeTextDark),
                      decoration: InputDecoration(
                        hintText: widget.seller ? 'Add a reply for your buyers...' : 'Add a reply for sellers...',
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
                    decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
                    child: IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: add),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.seller ? 'Shown behind ⚡ in chats where you sell.' : 'Shown behind ⚡ in chats where you buy.',
                      style: GoogleFonts.inter(fontSize: 12.5, color: context.themeTextLight),
                    ),
                  ),
                  if (hasOwn)
                    TextButton(
                      onPressed: () => _doc.update({_field: FieldValue.delete()}),
                      child: const Text('Reset'),
                    ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: replies.isEmpty
                  ? Center(child: Text('No quick replies yet.', style: GoogleFonts.inter(color: context.themeTextLight)))
                  : ListView.builder(
                      itemCount: replies.length,
                      itemBuilder: (context, index) {
                        final reply = replies[index];
                        return ListTile(
                          leading: const Icon(Icons.bolt_rounded, color: AppTheme.primary, size: 20),
                          title: Text(reply, style: GoogleFonts.inter(color: context.themeTextDark)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _save([...replies]..remove(reply)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
