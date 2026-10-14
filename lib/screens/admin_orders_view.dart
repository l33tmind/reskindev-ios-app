import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../models/order_model.dart';
import '../providers/chat_provider.dart';
import '../services/admin_order_status.dart';
import '../services/order_chat_nav.dart';
import '../widgets/user_avatar.dart';
import 'admin_users_view.dart';

/// Order groups the admin actually works with (real statuses, not the old pending / in_progress pair)
class AdminOrderFilter {
  final String label;
  final bool alert;
  final bool Function(OrderModel) test;
  const AdminOrderFilter(this.label, this.test, {this.alert = false});

  static final all = <AdminOrderFilter>[
    AdminOrderFilter('All', (_) => true),
    AdminOrderFilter('To verify', (o) => o.status == 'pending_payment' || o.status == 'pending', alert: true),
    AdminOrderFilter('Problems', (o) => o.status == 'disputed' || o.status.startsWith('cancel_requested'), alert: true),
    AdminOrderFilter('Active', (o) => const ['requirements', 'processing', 'in_progress', 'revision'].contains(o.status)),
    AdminOrderFilter('Delivered', (o) => o.status == 'delivered'),
    AdminOrderFilter('Completed', (o) => o.status == 'completed'),
    AdminOrderFilter('Cancelled', (o) => o.status == 'cancelled'),
  ];
}

class AdminOrdersView extends StatefulWidget {
  /// Opens on this filter (e.g. "To verify" from the overview)
  final String initialFilter;
  const AdminOrdersView({super.key, this.initialFilter = 'All'});

  @override
  State<AdminOrdersView> createState() => _AdminOrdersViewState();
}

class _AdminOrdersViewState extends State<AdminOrdersView> {
  late String _filter = widget.initialFilter;
  String _query = '';
  late final Stream<QuerySnapshot> _orders = FirebaseFirestore.instance.collection('orders').snapshots();

  @override
  void didUpdateWidget(covariant AdminOrdersView old) {
    super.didUpdateWidget(old);
    if (old.initialFilter != widget.initialFilter) _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    return StreamBuilder<QuerySnapshot>(
      stream: _orders,
      builder: (context, snap) {
        if (snap.hasError) return AdminErrorBox(error: snap.error);
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }
        final all = (snap.data?.docs ?? []).map(OrderModel.fromFirestore).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final filter = AdminOrderFilter.all.firstWhere((f) => f.label == _filter, orElse: () => AdminOrderFilter.all.first);
        final q = _query.trim().toLowerCase().replaceAll('#', '');
        final orders = all.where(filter.test).where((o) =>
            q.isEmpty ||
            o.userName.toLowerCase().contains(q) ||
            o.userEmail.toLowerCase().contains(q) ||
            o.gigTitle.toLowerCase().contains(q) ||
            (o.id ?? '').toLowerCase().endsWith(q) ||
            o.invoiceNumber.toLowerCase().contains(q)).toList();

        return ListView(
          padding: EdgeInsets.all(isMobile ? 16 : 40),
          children: [
            Text('Orders', style: GoogleFonts.outfit(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w800, color: context.themeTextDark)),
            const SizedBox(height: 4),
            Text('${all.length} orders · tap one for buyer, seller, requirements and actions.',
                style: GoogleFonts.inter(fontSize: 13.5, color: context.themeTextLight)),
            const SizedBox(height: 16),
            AdminSearchField(hint: 'Search buyer, email, gig, #order or invoice', onChanged: (v) => setState(() => _query = v)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final f in AdminOrderFilter.all)
                  AdminFilterChip(
                    label: f.label,
                    count: all.where(f.test).length,
                    selected: _filter == f.label,
                    alert: f.alert,
                    onTap: () => setState(() => _filter = f.label),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            if (orders.isEmpty)
              AdminEmpty(text: _filter == 'To verify' ? 'Nothing to verify. 🎉' : 'No orders here.')
            else
              AdminCard(children: [for (final o in orders) AdminOrderRow(order: o)]),
          ],
        );
      },
    );
  }
}

/// One order in a list: who, what, how much, where it is. Tap = full details + actions.
class AdminOrderRow extends StatelessWidget {
  final OrderModel order;
  final bool compact;
  const AdminOrderRow({super.key, required this.order, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final needsVerify = o.status == 'pending_payment' || o.status == 'pending';
    return InkWell(
      onTap: () => showAdminOrderSheet(context, o.id!),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.gigTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.themeTextDark)),
                  const SizedBox(height: 2),
                  Text('${adminOrderNo(o)} · ${o.userName.isEmpty ? 'Buyer' : o.userName} · ${adminDate(o.createdAt)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12.5, color: context.themeTextLight)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(adminMoney(o.price), style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                const SizedBox(height: 4),
                AdminPill(text: needsVerify ? 'Verify payment' : o.statusLabel, color: needsVerify ? Colors.orange : o.statusColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String adminOrderNo(OrderModel o) => '#${(o.id ?? '').length >= 6 ? o.id!.substring(o.id!.length - 6).toUpperCase() : o.id}';

void showAdminOrderSheet(BuildContext context, String orderId) {
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
      builder: (context, scroll) => _OrderSheet(orderId: orderId, scroll: scroll),
    ),
  );
}

class _OrderSheet extends StatefulWidget {
  final String orderId;
  final ScrollController scroll;
  const _OrderSheet({required this.orderId, required this.scroll});

  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  bool _working = false;

  static const _statuses = ['requirements', 'processing', 'revision', 'delivered', 'completed', 'disputed', 'cancelled'];

  Future<void> _run(OrderModel o, String status, {String? reason}) async {
    setState(() => _working = true);
    try {
      final chat = context.read<ChatProvider>();
      final refund = (o.status == 'pending_payment' || o.status == 'pending') && status == 'requirements'
          ? await AdminOrderStatus.verifyPayment(o, chat)
          : await AdminOrderStatus.set(o, status, chat, reason: reason ?? 'Changed by admin in the app');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(refund > 0
              ? 'Cancelled. ${adminMoney(refund)} refunded to the buyer\'s wallet.'
              : status == 'requirements' ? 'Payment verified. Buyer and seller were told.' : 'Order is now ${status.replaceAll('_', ' ')}.'),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _working = false);
  }

  /// Like the website: every manual change needs a short reason, cancelling says how much is refunded
  Future<void> _changeStatus(OrderModel o, String status) async {
    final ctrl = TextEditingController();
    final paid = o.status != 'pending_payment' && o.status != 'pending';
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Change to ${status.replaceAll('_', ' ')}?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: c.themeTextDark)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (status == 'cancelled')
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(paid ? 'The buyer gets ${adminMoney(o.price)} back in their wallet.' : 'Nothing was paid yet, so there is no refund.',
                  style: GoogleFonts.inter(fontSize: 13, color: c.themeTextLight)),
            ),
          TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Reason (shown in the order chat)', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Back')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().length >= 5) Navigator.pop(c, ctrl.text.trim());
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (reason != null) await _run(o, status, reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return AdminErrorBox(error: snap.error);
        if (!snap.hasData || !snap.data!.exists) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        final o = OrderModel.fromFirestore(snap.data!);
        final needsVerify = o.status == 'pending_payment' || o.status == 'pending';
        final d = snap.data!.data() as Map<String, dynamic>;
        final phone = (d['phone'] ?? '').toString();
        final serviceFee = ((d['serviceFee'] ?? 0) as num).toDouble();

        return ListView(
          controller: widget.scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.themeBorder, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Text('Order ${adminOrderNo(o)}',
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: context.themeTextDark)),
              ),
              AdminPill(text: needsVerify ? 'Payment pending' : o.statusLabel, color: needsVerify ? Colors.orange : o.statusColor),
            ]),
            const SizedBox(height: 4),
            Text(o.gigTitle, style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
            const SizedBox(height: 4),
            Text('${o.packageName.isEmpty ? '' : '${o.packageName} · '}${adminMoney(o.price)}'
                '${serviceFee > 0 ? ' (fee ${adminMoney(serviceFee)})' : ''} · ${adminDate(o.createdAt)}'
                '${o.invoiceNumber.isNotEmpty ? ' · ${o.invoiceNumber}' : ''}',
                style: GoogleFonts.inter(fontSize: 12.5, color: context.themeTextLight)),
            const SizedBox(height: 16),

            // The one thing to do now
            if (needsVerify) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Text('Check that you received ${adminMoney(o.price)} from ${o.userName.isEmpty ? 'the buyer' : o.userName}'
                    '${phone.isNotEmpty ? ' ($phone)' : ''}. Verifying tells both sides the seller can start.',
                    style: GoogleFonts.inter(fontSize: 13.5, height: 1.4, color: context.themeTextDark)),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _working ? null : () => _run(o, 'requirements'),
                icon: const Icon(Icons.verified_rounded),
                label: Text(_working ? 'Verifying…' : 'Verify payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // People
            Row(children: [
              Expanded(child: _Person(label: 'Buyer', uid: o.userId, fallback: o.userName, extra: o.userEmail.isNotEmpty ? o.userEmail : phone)),
              const SizedBox(width: 10),
              Expanded(child: _Person(label: 'Seller', uid: o.authorId, fallback: 'Seller')),
            ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => openOrderChat(context, o),
              icon: const Icon(Icons.forum_outlined, size: 18),
              label: const Text('Open order chat'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            if (o.projectDetails.trim().isNotEmpty) _Block(title: "Buyer's requirements", text: o.projectDetails),
            if (o.deliveryNote.trim().isNotEmpty) _Block(title: 'Delivery', text: o.deliveryNote),
            if ((d['revisionNote'] ?? '').toString().trim().isNotEmpty) _Block(title: 'Changes asked', text: d['revisionNote'].toString()),

            const SizedBox(height: 20),
            Text('CHANGE STATUS', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.themeTextLight)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in _statuses)
                if (s != o.status && !(o.status == 'completed' && s != 'disputed') && o.status != 'cancelled')
                  ActionChip(
                    label: Text(s == 'cancelled' ? 'Cancel & refund' : s[0].toUpperCase() + s.substring(1)),
                    labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: s == 'cancelled' ? AppTheme.error : context.themeTextDark),
                    side: BorderSide(color: s == 'cancelled' ? AppTheme.error.withValues(alpha: 0.5) : context.themeBorder),
                    onPressed: _working ? null : () => _changeStatus(o, s),
                  ),
            ]),
            if (o.status == 'cancelled')
              Text('Cancelled orders cannot be changed.', style: GoogleFonts.inter(fontSize: 12.5, color: context.themeTextLight)),
          ],
        );
      },
    );
  }
}

class _Person extends StatelessWidget {
  final String label;
  final String uid;
  final String fallback;
  final String? extra;
  const _Person({required this.label, required this.uid, required this.fallback, this.extra});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: uid.isEmpty ? null : () => showAdminUserSheet(context, uid),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: context.themeCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.themeBorder)),
        child: Row(children: [
          UserAvatar(uid: uid, name: fallback, radius: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: context.themeTextLight)),
              LiveUserName(uid: uid, fallback: fallback,
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.themeTextDark)),
              if (extra != null && extra!.isNotEmpty)
                Text(extra!, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11, color: context.themeTextLight)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  final String title;
  final String text;
  const _Block({required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.themeCard, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.themeTextLight)),
            const SizedBox(height: 4),
            SelectableText(text, style: GoogleFonts.inter(fontSize: 13.5, height: 1.4, color: context.themeTextDark)),
          ]),
        ),
      );
}

// ---------- Small shared admin pieces ----------

String adminMoney(double v) => '\$${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)}';

String adminDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

class AdminPill extends StatelessWidget {
  final String text;
  final Color color;
  const AdminPill({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      );
}

class AdminFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final bool alert;
  final VoidCallback onTap;
  const AdminFilterChip({super.key, required this.label, required this.count, required this.selected, required this.onTap, this.alert = false});

  @override
  Widget build(BuildContext context) {
    final red = alert && count > 0;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : context.themeSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppTheme.primary : context.themeBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : context.themeTextDark)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: red ? AppTheme.error : (selected ? Colors.white24 : context.themeCard),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                  color: red || selected ? Colors.white : context.themeTextLight)),
            ),
          ]),
        ),
      ),
    );
  }
}

class AdminSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const AdminSearchField({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) => TextField(
        onChanged: onChanged,
        style: GoogleFonts.inter(color: context.themeTextDark),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(Icons.search_rounded, color: context.themeTextLight),
          filled: true,
          fillColor: context.themeSurface,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.themeBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.themeBorder)),
        ),
      );
}

class AdminCard extends StatelessWidget {
  final List<Widget> children;
  const AdminCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.themeSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.themeBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: context.themeBorder.withValues(alpha: 0.6)),
            children[i],
          ],
        ]),
      );
}

class AdminEmpty extends StatelessWidget {
  final String text;
  const AdminEmpty({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(text, style: GoogleFonts.inter(color: context.themeTextLight))),
      );
}

/// Firestore errors used to be swallowed, which looked like an empty or half-empty list
class AdminErrorBox extends StatelessWidget {
  final Object? error;
  const AdminErrorBox({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    final denied = '$error'.contains('permission');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          denied
              ? 'Firebase refused this list. Check that this account has role "admin" in users/{uid}.'
              : 'Could not load: $error',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: AppTheme.error),
        ),
      ),
    );
  }
}
