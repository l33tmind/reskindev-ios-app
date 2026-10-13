import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../models/order_model.dart';
import '../widgets/user_avatar.dart';
import 'admin_orders_view.dart';
import '../services/pro_service.dart';
import '../services/pro_service.dart' as pro_svc show isPro;
import '../widgets/pro_badge.dart';

/// One row of users/{uid}, read the same way on every platform
class AdminUser {
  final String uid;
  final String name;
  final String email;
  final String username;
  final String photoUrl;
  final String role;
  final bool isGuest;
  final bool blocked;
  final bool verified;
  final double wallet;
  final DateTime? joined;
  final DateTime? lastLogin;
  final String phone;
  final String country;
  /// Reskindev Pro: active and not expired
  final bool isPro;
  final DateTime? proExpires;
  final String proSource;
  final String proPlan;

  AdminUser.fromDoc(DocumentSnapshot doc)
      : uid = doc.id,
        name = _str(doc, ['displayName', 'name']).isNotEmpty ? _str(doc, ['displayName', 'name']) : 'Unnamed user',
        email = _str(doc, ['email']),
        username = _str(doc, ['username']),
        photoUrl = _str(doc, ['photoURL', 'photoUrl']),
        role = _str(doc, ['role']).isEmpty ? 'buyer' : _str(doc, ['role']),
        isGuest = (doc.data() as Map<String, dynamic>?)?['isGuest'] == true,
        // The app wrote isBlocked, the website writes status: "blocked" (+ banned). Either counts.
        blocked = _map(doc)['isBlocked'] == true || _map(doc)['status'] == 'blocked' || _map(doc)['banned'] == true,
        verified = _map(doc)['verified'] == true,
        wallet = ((_map(doc)['walletBalance'] ?? 0) as num).toDouble(),
        joined = _date(_map(doc)['createdAt']),
        lastLogin = _date(_map(doc)['lastLogin']),
        phone = _str(doc, ['phone']),
        country = _str(doc, ['country']),
        isPro = pro_svc.isPro(_map(doc)),
        proExpires = proExpiresAt(_map(doc)),
        proSource = (proOf(_map(doc))?['source'] ?? '').toString(),
        proPlan = (proOf(_map(doc))?['plan'] ?? '').toString();

  bool get isAdmin => role == 'admin';
  bool get isSeller => role == 'freelancer' || role == 'admin';

  static Map<String, dynamic> _map(DocumentSnapshot d) => (d.data() as Map<String, dynamic>?) ?? {};
  static String _str(DocumentSnapshot d, List<String> keys) {
    for (final k in keys) {
      final v = _map(d)[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  static DateTime? _date(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

/// Block / unblock the same way as the website (status + banned), plus the app's own isBlocked flag
Future<void> adminSetBlocked(BuildContext context, AdminUser user, bool block) async {
  try {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'isBlocked': block,
      'status': block ? 'blocked' : 'active',
      'banned': block,
      'statusChangedAt': FieldValue.serverTimestamp(),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name} is now ${block ? 'blocked' : 'active'}.')),
      );
    }
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}

class AdminUsersView extends StatefulWidget {
  const AdminUsersView({super.key});

  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<AdminUsersView> {
  static const _filters = ['All', 'Buyers', 'Sellers', 'Pro', 'Admins', 'Guests', 'Blocked'];
  String _filter = 'All';
  String _query = '';
  late final Stream<QuerySnapshot> _users = FirebaseFirestore.instance.collection('users').snapshots();

  bool _matches(AdminUser u, String filter) {
    switch (filter) {
      case 'Buyers': return !u.isSeller && !u.isGuest;
      case 'Sellers': return u.role == 'freelancer' && !u.isGuest;
      case 'Pro': return u.isPro;
      case 'Admins': return u.isAdmin;
      case 'Guests': return u.isGuest;
      case 'Blocked': return u.blocked;
      default: return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    return StreamBuilder<QuerySnapshot>(
      stream: _users,
      builder: (context, snap) {
        if (snap.hasError) return AdminErrorBox(error: snap.error);
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }
        final all = (snap.data?.docs ?? []).map(AdminUser.fromDoc).toList()
          ..sort((a, b) => (b.joined ?? DateTime(2000)).compareTo(a.joined ?? DateTime(2000)));
        final q = _query.trim().toLowerCase();
        final users = all.where((u) => _matches(u, _filter)).where((u) =>
            q.isEmpty || u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q) ||
            u.username.toLowerCase().contains(q) || u.phone.contains(q)).toList();

        return ListView(
          padding: EdgeInsets.all(isMobile ? 16 : 40),
          children: [
            Text('Users', style: GoogleFonts.outfit(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w800, color: context.themeTextDark)),
            const SizedBox(height: 4),
            Text('${all.length} accounts · tap anyone to see their orders, gigs and wallet.',
                style: GoogleFonts.inter(fontSize: 13.5, color: context.themeTextLight)),
            const SizedBox(height: 16),
            AdminSearchField(hint: 'Search name, email, @username or phone', onChanged: (v) => setState(() => _query = v)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in _filters)
                    AdminFilterChip(
                      label: f,
                      count: all.where((u) => _matches(u, f)).length,
                      selected: _filter == f,
                      alert: f == 'Blocked',
                      onTap: () => setState(() => _filter = f),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (users.isEmpty)
              const AdminEmpty(text: 'No users here.')
            else
              AdminCard(
                children: [
                  for (final u in users) _UserRow(user: u),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _UserRow extends StatelessWidget {
  final AdminUser user;
  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showAdminUserSheet(context, user.uid),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            UserAvatar(uid: user.uid, name: user.name, photoUrl: user.photoUrl, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: context.themeTextDark)),
                      ),
                      if (user.verified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, size: 15, color: AppTheme.info),
                      ],
                      if (user.isPro) ...[
                        const SizedBox(width: 6),
                        const ProBadge(fontSize: 9),
                      ],
                    ],
                  ),
                  Text(user.email.isNotEmpty ? user.email : (user.username.isNotEmpty ? '@${user.username}' : 'No email'),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12.5, color: context.themeTextLight)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AdminPill(text: user.blocked ? 'Blocked' : roleLabel(user), color: user.blocked ? AppTheme.error : roleColor(user)),
            Icon(Icons.chevron_right_rounded, color: context.themeTextLight),
          ],
        ),
      ),
    );
  }
}

String roleLabel(AdminUser u) => u.isAdmin ? 'Admin' : u.isGuest ? 'Guest' : u.role == 'freelancer' ? 'Seller' : 'Buyer';
Color roleColor(AdminUser u) => u.isAdmin ? Colors.purple : u.isGuest ? Colors.grey : u.role == 'freelancer' ? AppTheme.primary : AppTheme.info;

/// Everything about one person: as a buyer, as a seller, their gigs and wallet, and the admin actions
void showAdminUserSheet(BuildContext context, String uid) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.themeSurface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, scroll) => _UserSheet(uid: uid, scroll: scroll),
    ),
  );
}

class _UserSheet extends StatelessWidget {
  final String uid;
  final ScrollController scroll;
  const _UserSheet({required this.uid, required this.scroll});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        final u = AdminUser.fromDoc(userSnap.data!);
        return StreamBuilder<QuerySnapshot>(
          stream: db.collection('orders').where('userId', isEqualTo: uid).snapshots(),
          builder: (context, buySnap) => StreamBuilder<QuerySnapshot>(
            stream: db.collection('orders').where('authorId', isEqualTo: uid).snapshots(),
            builder: (context, sellSnap) => StreamBuilder<QuerySnapshot>(
              stream: db.collection('services').where('authorId', isEqualTo: uid).snapshots(),
              builder: (context, gigSnap) {
                final bought = (buySnap.data?.docs ?? []).map(OrderModel.fromFirestore).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                final sold = (sellSnap.data?.docs ?? []).map(OrderModel.fromFirestore).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                final gigs = gigSnap.data?.docs ?? [];
                final spent = bought.where((o) => o.status == 'completed').fold<double>(0, (s, o) => s + o.price);
                final earned = sold.where((o) => o.status == 'completed').fold<double>(0, (s, o) => s + o.price);

                return ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.themeBorder, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        UserAvatar(uid: u.uid, name: u.name, photoUrl: u.photoUrl, radius: 30),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.name, style: GoogleFonts.outfit(fontSize: 21, fontWeight: FontWeight.w800, color: context.themeTextDark)),
                              if (u.username.isNotEmpty)
                                Text('@${u.username}', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
                              const SizedBox(height: 6),
                              Wrap(spacing: 6, runSpacing: 6, children: [
                                AdminPill(text: roleLabel(u), color: roleColor(u)),
                                if (u.blocked) const AdminPill(text: 'Blocked', color: AppTheme.error),
                                if (u.verified) const AdminPill(text: 'Verified', color: AppTheme.info),
                                if (u.isPro) const ProBadge(fontSize: 10.5),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InfoLine(icon: Icons.mail_outline_rounded, text: u.email.isEmpty ? 'No email (guest)' : u.email),
                    if (u.phone.isNotEmpty) _InfoLine(icon: Icons.phone_outlined, text: u.phone),
                    if (u.country.isNotEmpty) _InfoLine(icon: Icons.public_rounded, text: u.country),
                    _InfoLine(icon: Icons.calendar_today_outlined,
                        text: 'Joined ${u.joined != null ? adminDate(u.joined!) : 'unknown'}'
                            '${u.lastLogin != null ? ' · last seen ${adminDate(u.lastLogin!)}' : ''}'),
                    const SizedBox(height: 16),
                    // Numbers at a glance
                    Row(children: [
                      Expanded(child: _Stat(label: 'Wallet', value: adminMoney(u.wallet))),
                      const SizedBox(width: 8),
                      Expanded(child: _Stat(label: 'Bought', value: '${bought.length}', sub: adminMoney(spent))),
                      const SizedBox(width: 8),
                      Expanded(child: _Stat(label: 'Sold', value: '${sold.length}', sub: adminMoney(earned))),
                      const SizedBox(width: 8),
                      Expanded(child: _Stat(label: 'Gigs', value: '${gigs.length}')),
                    ]),
                    const SizedBox(height: 16),
                    if (!u.isAdmin)
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => FirebaseFirestore.instance.collection('users').doc(u.uid).update({'verified': !u.verified}),
                            icon: Icon(u.verified ? Icons.remove_moderator_outlined : Icons.verified_outlined, size: 18),
                            label: Text(u.verified ? 'Unverify' : 'Verify'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.info,
                              side: BorderSide(color: AppTheme.info.withValues(alpha: 0.5)),
                              minimumSize: const Size(0, 44),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _confirmBlock(context, u),
                            icon: Icon(u.blocked ? Icons.lock_open_rounded : Icons.block_rounded, size: 18),
                            label: Text(u.blocked ? 'Unblock' : 'Block'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: u.blocked ? AppTheme.success : AppTheme.error,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size(0, 44),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ]),
                    _ProAdminBox(user: u),
                    _Section(title: 'Orders as buyer (${bought.length})'),
                    if (bought.isEmpty) const AdminEmpty(text: 'No orders placed.'),
                    for (final o in bought.take(20)) AdminOrderRow(order: o, compact: true),
                    _Section(title: 'Orders as seller (${sold.length})'),
                    if (sold.isEmpty) const AdminEmpty(text: 'No orders received.'),
                    for (final o in sold.take(20)) AdminOrderRow(order: o, compact: true),
                    _Section(title: 'Gigs (${gigs.length})'),
                    if (gigs.isEmpty) const AdminEmpty(text: 'No gigs.'),
                    for (final g in gigs) _GigLine(doc: g),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmBlock(BuildContext context, AdminUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(u.blocked ? 'Unblock ${u.name}?' : 'Block ${u.name}?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: c.themeTextDark)),
        content: Text(u.blocked
            ? 'They can sign in, order and message again.'
            : 'They can no longer order, sell or message on the app, website or Vision Pro.',
            style: GoogleFonts.inter(color: c.themeTextLight)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: Text(u.blocked ? 'Unblock' : 'Block')),
        ],
      ),
    );
    if (ok == true && context.mounted) await adminSetBlocked(context, u, !u.blocked);
  }
}

class _GigLine extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _GigLine({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final status = (d['status'] ?? 'active').toString();
    final color = status == 'pending' ? Colors.orange : status == 'active' || status == 'published' ? AppTheme.success : AppTheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(Icons.work_outline_rounded, size: 18, color: context.themeTextLight),
        const SizedBox(width: 10),
        Expanded(child: Text((d['title'] ?? 'Untitled').toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 14, color: context.themeTextDark))),
        AdminPill(text: status[0].toUpperCase() + status.substring(1), color: color),
      ]),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(icon, size: 16, color: context.themeTextLight),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(text, style: GoogleFonts.inter(fontSize: 13.5, color: context.themeTextDark))),
        ]),
      );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  const _Stat({required this.label, required this.value, this.sub});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(color: context.themeCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.themeBorder)),
        child: Column(children: [
          Text(value, maxLines: 1, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: context.themeTextDark)),
          Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: context.themeTextLight)),
          if (sub != null) Text(sub!, maxLines: 1, style: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.success)),
        ]),
      );
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 6),
        child: Text(title.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.themeTextLight)),
      );
}

/// Reskindev Pro status of one person + Give / Remove (adminSetPro callable).
class _ProAdminBox extends StatefulWidget {
  final AdminUser user;
  const _ProAdminBox({required this.user});

  @override
  State<_ProAdminBox> createState() => _ProAdminBoxState();
}

class _ProAdminBoxState extends State<_ProAdminBox> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(proErrorMessage(e)), backgroundColor: AppTheme.error));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final source = switch (u.proSource) {
      'apple' => 'App Store',
      'google' => 'Google Play',
      'wallet' => 'wallet',
      'admin' => 'admin gift',
      _ => u.proSource,
    };
    final String status;
    if (u.isPro) {
      status = 'Pro${u.proPlan.isNotEmpty ? ' · ${u.proPlan}' : ''}${source.isNotEmpty ? ' · $source' : ''}'
          '${u.proExpires != null ? ' · until ${adminDate(u.proExpires!)}' : ''}';
    } else if (u.proExpires != null) {
      status = 'Not Pro · ended ${adminDate(u.proExpires!)}';
    } else {
      status = 'Not Pro';
    }

    ButtonStyle outlined(Color c) => OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(color: c.withValues(alpha: 0.5)),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Section(title: 'Reskindev Pro'),
        Row(children: [
          Icon(Icons.bolt_rounded, size: 18, color: u.isPro ? ProBadge.amber : context.themeTextLight),
          const SizedBox(width: 8),
          Expanded(child: Text(status, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.themeTextDark))),
          if (_busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : () => _run(() => ProService.adminGivePro(u.uid, 30), '${u.name} has Pro for 30 days.'),
              style: outlined(ProBadge.amberDark),
              child: const Text('Give Pro 30 days', textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : () => _run(() => ProService.adminGivePro(u.uid, 365), '${u.name} has Pro for 1 year.'),
              style: outlined(ProBadge.amberDark),
              child: const Text('Give Pro 1 year', textAlign: TextAlign.center),
            ),
          ),
          if (u.isPro) ...[
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _run(() => ProService.adminRemovePro(u.uid), 'Pro removed from ${u.name}.'),
                style: outlined(AppTheme.error),
                child: const Text('Remove Pro', textAlign: TextAlign.center),
              ),
            ),
          ],
        ]),
      ],
    );
  }
}
