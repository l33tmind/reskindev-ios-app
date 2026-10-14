import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/pro_service.dart';
import '../services/verification_service.dart';
import '../theme.dart';
import '../widgets/pro_badge.dart';
import '../widgets/user_avatar.dart';
import 'admin_orders_view.dart';
import 'admin_users_view.dart';

/// Identity verification requests (blue tick): Pending / Approved / Rejected / All.
class AdminVerificationsView extends StatefulWidget {
  const AdminVerificationsView({super.key});

  @override
  State<AdminVerificationsView> createState() => _AdminVerificationsViewState();
}

class _AdminVerificationsViewState extends State<AdminVerificationsView> {
  static const _filters = ['Pending', 'Approved', 'Rejected', 'All'];
  String _filter = 'Pending';
  String _query = '';
  late final Stream<QuerySnapshot> _stream = FirebaseFirestore.instance.collection('verifications').snapshots();

  bool _matches(VerificationRequest r, String f) {
    switch (f) {
      case 'Pending':
        return r.status == 'pending';
      case 'Approved':
        return r.status == 'approved';
      case 'Rejected':
        return r.status == 'rejected' || r.status == 'revoked';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return AdminErrorBox(error: snap.error);
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }
        final all = (snap.data?.docs ?? []).map(VerificationRequest.fromDoc).toList()
          ..sort((a, b) => (b.submittedAt ?? DateTime(2000)).compareTo(a.submittedAt ?? DateTime(2000)));
        final q = _query.trim().toLowerCase();
        final list = all
            .where((r) => _matches(r, _filter))
            .where((r) =>
                q.isEmpty ||
                r.name.toLowerCase().contains(q) ||
                r.legalName.toLowerCase().contains(q) ||
                r.email.toLowerCase().contains(q))
            .toList();

        return ListView(
          padding: EdgeInsets.all(isMobile ? 16 : 40),
          children: [
            Text('Verifications',
                style: GoogleFonts.outfit(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w800, color: context.themeTextDark)),
            const SizedBox(height: 4),
            Text('Pro members asking for the blue tick. Check the ID and selfie, then approve or reject.',
                style: GoogleFonts.inter(fontSize: 13.5, color: context.themeTextLight)),
            const SizedBox(height: 16),
            AdminSearchField(hint: 'Search name or email', onChanged: (v) => setState(() => _query = v)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final f in _filters)
                  AdminFilterChip(
                    label: f,
                    count: all.where((r) => _matches(r, f)).length,
                    selected: _filter == f,
                    alert: f == 'Pending',
                    onTap: () => setState(() => _filter = f),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              AdminEmpty(text: _filter == 'Pending' ? 'No requests waiting.' : 'Nothing here.')
            else
              AdminCard(children: [for (final r in list) _RequestRow(request: r)]),
          ],
        );
      },
    );
  }
}

Color verificationColor(String status) => switch (status) {
      'approved' => VerifiedTick.blue,
      'pending' => Colors.orange,
      'rejected' || 'revoked' => AppTheme.error,
      _ => Colors.grey,
    };

String verificationLabel(String status) => switch (status) {
      'approved' => 'Verified',
      'pending' => 'Pending',
      'rejected' => 'Rejected',
      'revoked' => 'Revoked',
      _ => status,
    };

class _RequestRow extends StatelessWidget {
  final VerificationRequest request;
  const _RequestRow({required this.request});

  @override
  Widget build(BuildContext context) {
    final r = request;
    return InkWell(
      onTap: () => showAdminVerificationSheet(context, r.uid),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          UserAvatar(uid: r.uid, name: r.displayName, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(r.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: context.themeTextDark)),
                ),
                if (r.isPro) ...[const SizedBox(width: 6), const ProBadge(fontSize: 9)],
              ]),
              Text(
                [
                  if (r.email.isNotEmpty) r.email,
                  if (r.country.isNotEmpty) r.country,
                  if (r.submittedAt != null) adminDate(r.submittedAt!),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12.5, color: context.themeTextLight),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          AdminPill(text: verificationLabel(r.status), color: verificationColor(r.status)),
          Icon(Icons.chevron_right_rounded, color: context.themeTextLight),
        ]),
      ),
    );
  }
}

/// One verification request with the photos and Approve / Reject / Revoke.
void showAdminVerificationSheet(BuildContext context, String uid) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.themeSurface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      builder: (context, scroll) => _VerificationSheet(uid: uid, scroll: scroll),
    ),
  );
}

class _VerificationSheet extends StatefulWidget {
  final String uid;
  final ScrollController scroll;
  const _VerificationSheet({required this.uid, required this.scroll});

  @override
  State<_VerificationSheet> createState() => _VerificationSheetState();
}

class _VerificationSheetState extends State<_VerificationSheet> {
  bool _busy = false;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _stream = VerificationService.docFor(widget.uid).snapshots();

  Future<String?> _askReason(String title, String action) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          backgroundColor: c.themeSurface,
          title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: c.themeTextDark)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('They will see this reason.', style: GoogleFonts.inter(fontSize: 13, color: c.themeTextLight)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              minLines: 2,
              onChanged: (_) => setD(() {}),
              style: GoogleFonts.inter(color: c.themeTextDark),
              decoration: InputDecoration(
                hintText: 'e.g. The ID photo is blurry, please retake it in good light',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: ctrl.text.trim().length < 5 ? null : () => Navigator.pop(c, ctrl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
              child: Text(action),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    return reason;
  }

  Future<void> _decide(VerificationRequest r, String decision) async {
    String? reason;
    if (decision == 'reject') {
      reason = await _askReason('Reject ${r.displayName}?', 'Reject');
      if (reason == null) return;
    } else if (decision == 'revoke') {
      reason = await _askReason('Remove the blue tick from ${r.displayName}?', 'Revoke');
      if (reason == null) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await VerificationService.review(r.uid, decision, reason: reason);
      messenger.showSnackBar(SnackBar(
        content: Text(switch (decision) {
          'approve' => '${r.displayName} is verified.',
          'reject' => 'Request rejected. ${r.displayName} can send it again.',
          _ => 'Blue tick removed from ${r.displayName}.',
        }),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(proErrorMessage(e)), backgroundColor: AppTheme.error));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return AdminErrorBox(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        if (!snap.data!.exists) {
          return ListView(controller: widget.scroll, children: const [AdminEmpty(text: 'No verification request for this person.')]);
        }
        final r = VerificationRequest.fromDoc(snap.data!);
        final passport = r.idType == 'passport';
        return ListView(
          controller: widget.scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                  width: 40, height: 4, decoration: BoxDecoration(color: context.themeBorder, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Row(children: [
              UserAvatar(uid: r.uid, name: r.displayName, radius: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.displayName,
                      style: GoogleFonts.outfit(fontSize: 21, fontWeight: FontWeight.w800, color: context.themeTextDark)),
                  if (r.email.isNotEmpty)
                    SelectableText(r.email, style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    AdminPill(text: verificationLabel(r.status), color: verificationColor(r.status)),
                    if (r.isPro) const ProBadge(fontSize: 10.5),
                  ]),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showAdminUserSheet(context, r.uid),
                icon: const Icon(Icons.person_outline_rounded, size: 18),
                label: const Text('Open user details'),
              ),
            ),
            _Section('Details'),
            _Field('Legal name', r.legalName),
            _Field('Date of birth', r.dateOfBirth),
            _Field('ID type', idTypeLabel(r.idType)),
            _Field('Country', r.country),
            _Field('Address', r.address),
            if (r.submittedAt != null) _Field('Sent', adminDate(r.submittedAt!)),
            if (r.reviewedAt != null)
              _Field('Reviewed', '${adminDate(r.reviewedAt!)}${r.reviewedByName.isNotEmpty ? ' by ${r.reviewedByName}' : ''}'),
            if (r.rejectReason.isNotEmpty && (r.status == 'rejected' || r.status == 'revoked'))
              _Field('Reason', r.rejectReason),
            _Section('Photos'),
            LayoutBuilder(builder: (context, c) {
              final tiles = [
                _StoragePhoto(path: r.idFront, label: passport ? 'Passport' : 'ID front'),
                if (!passport || r.idBack.isNotEmpty) _StoragePhoto(path: r.idBack, label: 'ID back'),
                _StoragePhoto(path: r.selfie, label: 'Selfie with ID'),
              ];
              final w = (c.maxWidth - 10 * (tiles.length - 1)) / tiles.length;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < tiles.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    SizedBox(width: w, child: tiles[i]),
                  ],
                ],
              );
            }),
            const SizedBox(height: 22),
            if (_busy)
              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: AppTheme.primary)))
            else if (r.status == 'pending')
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _decide(r, 'reject'),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: BorderSide(color: AppTheme.error.withValues(alpha: 0.5)),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _decide(r, 'approve'),
                    icon: const Icon(Icons.verified_rounded, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ])
            else if (r.status == 'approved')
              OutlinedButton.icon(
                onPressed: () => _decide(r, 'revoke'),
                icon: const Icon(Icons.remove_moderator_outlined, size: 18),
                label: const Text('Revoke blue tick'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: BorderSide(color: AppTheme.error.withValues(alpha: 0.5)),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            else
              Text('Waiting for them to send it again.',
                  textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
            if (r.history.isNotEmpty) ...[
              _Section('History'),
              for (final h in r.history.reversed) _HistoryLine(entry: h),
            ],
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(title.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.themeTextLight)),
      );
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  const _Field(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 110,
            child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
          ),
          Expanded(
            child: SelectableText(value.isEmpty ? '—' : value,
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.themeTextDark)),
          ),
        ]),
      );
}

class _HistoryLine extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _HistoryLine({required this.entry});

  @override
  Widget build(BuildContext context) {
    final at = entry['at'] ?? entry['date'] ?? entry['submittedAt'] ?? entry['reviewedAt'];
    DateTime? d;
    if (at is Timestamp) d = at.toDate();
    if (at is String) d = DateTime.tryParse(at);
    if (at is num) d = DateTime.fromMillisecondsSinceEpoch(at.toInt());
    final what = (entry['status'] ?? entry['action'] ?? entry['decision'] ?? '').toString();
    final by = (entry['byName'] ?? entry['reviewedByName'] ?? '').toString();
    final reason = (entry['reason'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.circle, size: 8, color: verificationColor(what)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            [
              if (d != null) adminDate(d),
              if (what.isNotEmpty) what[0].toUpperCase() + what.substring(1),
              if (by.isNotEmpty) 'by $by',
              if (reason.isNotEmpty) '“$reason”',
            ].join(' · '),
            style: GoogleFonts.inter(fontSize: 12.5, color: context.themeTextDark),
          ),
        ),
      ]),
    );
  }
}

/// A private verification photo, read through the Storage SDK (admins are allowed). Tap to enlarge.
class _StoragePhoto extends StatefulWidget {
  final String path;
  final String label;
  const _StoragePhoto({required this.path, required this.label});

  @override
  State<_StoragePhoto> createState() => _StoragePhotoState();
}

class _StoragePhotoState extends State<_StoragePhoto> {
  late Future<String?> _url = _load();

  Future<String?> _load() async {
    if (widget.path.isEmpty) return null;
    return FirebaseStorage.instance.ref(widget.path).getDownloadURL();
  }

  @override
  void didUpdateWidget(covariant _StoragePhoto old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _url = _load();
  }

  void _open(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (c) => Stack(children: [
        Positioned.fill(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 6,
            child: Center(child: Image.network(url, fit: BoxFit.contain)),
          ),
        ),
        Positioned(
          top: MediaQuery.of(c).padding.top + 8,
          right: 8,
          child: IconButton(
            onPressed: () => Navigator.pop(c),
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.of(c).padding.bottom + 16,
          child: Text(widget.label,
              textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: context.themeCard,
            child: FutureBuilder<String?>(
              future: _url,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                }
                final url = snap.data;
                if (snap.hasError || url == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(widget.path.isEmpty ? 'Not sent' : 'Could not load',
                          textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
                    ),
                  );
                }
                return GestureDetector(
                  onTap: () => _open(url),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (c, child, p) =>
                        p == null ? child : const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                    errorBuilder: (c, e, st) => Center(child: Icon(Icons.broken_image_outlined, color: context.themeTextLight)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(widget.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.themeTextDark)),
    ]);
  }
}
