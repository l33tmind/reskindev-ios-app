import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../services/pro_service.dart';
import '../services/verification_service.dart';
import '../widgets/pro_badge.dart';
import 'admin_orders_view.dart';
import 'admin_users_view.dart';

/// Support tickets: priority (Pro members) first, then newest.
class AdminSupportTicketsView extends StatelessWidget {
  const AdminSupportTicketsView({super.key});

  static DateTime _created(Map<String, dynamic> d) {
    final v = d['createdAt'];
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime(2000);
    return DateTime.now(); // pending server timestamp = just created
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Support Tickets', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: context.themeTextDark)),
          const SizedBox(height: 8),
          Text('Manage disputes and user issues. Priority tickets from Pro members come first.',
              style: GoogleFonts.inter(color: context.themeTextLight)),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('support_tickets').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return AdminErrorBox(error: snapshot.error);
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator.adaptive());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No support tickets found.'));
                }
                final docs = snapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final da = a.data() as Map<String, dynamic>;
                    final db = b.data() as Map<String, dynamic>;
                    final pa = da['priority'] == true ? 0 : 1;
                    final pb = db['priority'] == true ? 0 : 1;
                    if (pa != pb) return pa.compareTo(pb);
                    return _created(db).compareTo(_created(da));
                  });

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) => _TicketCard(doc: docs[index]),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

class _TicketCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const _TicketCard({required this.doc});

  @override
  State<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<_TicketCard> {
  bool _busy = false;

  Future<void> _togglePriority(bool priority) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await VerificationService.setTicketPriority(widget.doc.id, priority);
      messenger.showSnackBar(SnackBar(content: Text(priority ? 'Marked as priority.' : 'Priority removed.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(proErrorMessage(e)), backgroundColor: AppTheme.error));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final status = (data['status'] ?? 'open').toString();
    final priority = data['priority'] == true;
    final isPro = data['isPro'] == true;
    final gigTitle = (data['gigTitle'] ?? '').toString();
    final reporter = (data['reportedByUid'] ?? '').toString();
    final created = data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: context.themeSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: priority ? ProBadge.amber.withValues(alpha: 0.7) : context.themeBorder, width: priority ? 1.4 : 1),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text((data['subject'] ?? 'No Subject').toString(),
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                ),
                const SizedBox(width: 8),
                AdminPill(text: status.toUpperCase(), color: status == 'open' ? Colors.red : Colors.green),
              ],
            ),
            if (priority || isPro) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (priority) const AdminPill(text: 'PRIORITY', color: ProBadge.amberDark),
                if (isPro) const ProBadge(fontSize: 9.5),
              ]),
            ],
            const SizedBox(height: 8),
            if (gigTitle.isNotEmpty)
              Text('Order: $gigTitle', style: GoogleFonts.inter(color: context.themeTextLight, fontSize: 13)),
            if (created != null)
              Text('Sent ${adminDate(created)}', style: GoogleFonts.inter(color: context.themeTextLight, fontSize: 12.5)),
            const SizedBox(height: 8),
            Text((data['description'] ?? '').toString(), style: GoogleFonts.inter(color: context.themeTextDark)),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 4,
              children: [
                if (reporter.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => showAdminUserSheet(context, reporter),
                    icon: const Icon(Icons.person_outline_rounded, size: 18),
                    label: const Text('Who sent it'),
                  ),
                TextButton.icon(
                  onPressed: _busy ? null : () => _togglePriority(!priority),
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(priority ? Icons.flag_outlined : Icons.flag_rounded, size: 18),
                  label: Text(priority ? 'Remove priority' : 'Set priority'),
                  style: TextButton.styleFrom(foregroundColor: ProBadge.amberDark),
                ),
                if (status == 'open')
                  TextButton(
                    onPressed: () => FirebaseFirestore.instance
                        .collection('support_tickets')
                        .doc(widget.doc.id)
                        .update({'status': 'resolved'}),
                    style: TextButton.styleFrom(foregroundColor: Colors.green),
                    child: const Text('Mark as Resolved'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
