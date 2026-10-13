import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/notification_feed.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';

/// Icon + colour for each kind of notification.
class _Kind {
  final IconData icon;
  final Color color;
  const _Kind(this.icon, this.color);
}

_Kind _kindFor(AppNotif n) {
  var type = n.type == 'order' && n.title.toLowerCase().contains('complete') ? 'completed' : n.type;
  if (type.isEmpty || type == 'order') {
    // Older notifications saved before specific types existed: guess from the title
    final t = n.title.toLowerCase();
    if (t.contains('payment') || t.contains('escrow')) {
      type = 'payment';
    } else if (t.contains('placed') || t.contains('new order')) {
      type = 'order';
    } else if (t.contains('started')) {
      type = 'started';
    } else if (t.contains('deliver')) {
      type = 'delivery';
    } else if (t.contains('revision')) {
      type = 'revision';
    } else if (t.contains('complete')) {
      type = 'completed';
    } else if (t.contains('review')) {
      type = 'review';
    }
  }
  switch (type) {
    case 'order':
      return const _Kind(Icons.shopping_bag_rounded, Color(0xFFF59E0B));
    case 'payment':
      return const _Kind(Icons.verified_user_rounded, Color(0xFF10B981));
    case 'requirements':
      return const _Kind(Icons.assignment_rounded, Color(0xFF3B82F6));
    case 'started':
      return const _Kind(Icons.play_circle_rounded, Color(0xFF3B82F6));
    case 'delivery':
      return const _Kind(Icons.inventory_2_rounded, Color(0xFF8B5CF6));
    case 'revision':
      return const _Kind(Icons.replay_rounded, Color(0xFFF97316));
    case 'completed':
      return const _Kind(Icons.check_circle_rounded, Color(0xFF10B981));
    case 'review':
      return const _Kind(Icons.star_rounded, Color(0xFFFFB33E));
    default:
      return const _Kind(Icons.notifications_rounded, AppTheme.primary);
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _sectionOf(DateTime? t) {
    if (t == null) return 'Earlier';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'This week';
    return 'Earlier';
  }

  Future<void> _markAllRead(List<AppNotif> items) async {
    final unread = items.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    HapticFeedback.selectionClick();
    await Future.wait(unread.map((n) => n.markRead()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: context.themeBackground,
      body: auth.user == null
          ? Center(child: Text('Please login to view notifications', style: GoogleFonts.inter(color: context.themeTextLight)))
          : StreamBuilder<List<AppNotif>>(
              stream: AppNotif.stream(auth.user!.uid),
              builder: (context, snapshot) {
                final docs = snapshot.data ?? [];
                final unread = docs.where((n) => !n.read).length;

                // Group into Today / Yesterday / This week / Earlier
                final rows = <Object>[];
                String? last;
                for (final d in docs) {
                  final section = _sectionOf(d.createdAt);
                  if (section != last) {
                    rows.add(section);
                    last = section;
                  }
                  rows.add(d);
                }

                return CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      backgroundColor: context.themeBackground,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      iconTheme: IconThemeData(color: context.themeTextDark),
                      title: Text('Notifications', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.themeTextDark)),
                      centerTitle: true,
                      actions: [
                        if (unread > 0)
                          TextButton(
                            onPressed: () => _markAllRead(docs),
                            child: Text('Read all', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.primary)),
                          ),
                      ],
                    ),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator.adaptive()))
                    else if (docs.isEmpty)
                      SliverFillRemaining(hasScrollBody: false, child: _EmptyState())
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        sliver: SliverList.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, i) {
                            final row = rows[i];
                            if (row is String) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
                                child: Text(
                                  row.toUpperCase(),
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: context.themeTextLight),
                                ),
                              );
                            }
                            return _NotificationCard(item: row as AppNotif);
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.notifications_none_rounded, size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 20),
          Text("You're all caught up", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: context.themeTextDark)),
          const SizedBox(height: 8),
          Text(
            'Order updates, payments and deliveries will show up here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: context.themeTextLight),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotif item;
  const _NotificationCard({required this.item});

  Widget _chip(BuildContext context, String text, {bool strong = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.themeTextDark.withValues(alpha: strong ? 0.09 : 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
          color: context.themeTextDark.withValues(alpha: 0.75),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  /// Full notification: whole text, exact time, order + invoice number and a button to open the chat.
  void _showDetails(BuildContext context, _Kind kind) {
    final time = item.createdAt;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.themeSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.8),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: context.themeBorder, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: kind.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                      child: Icon(kind.icon, color: kind.color, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: context.themeTextDark)),
                          if (time != null) ...[
                            const SizedBox(height: 2),
                            Text(DateFormat('d MMM yyyy, h:mm a').format(time), style: GoogleFonts.inter(fontSize: 12.5, color: context.themeTextLight)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (item.orderNumber.isNotEmpty || item.invoiceNumber.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (item.orderNumber.isNotEmpty) _chip(context, 'Order ${item.orderNumber}', strong: true),
                      if (item.invoiceNumber.isNotEmpty) _chip(context, item.invoiceNumber),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                SelectableText(
                  item.body,
                  style: GoogleFonts.inter(fontSize: 15, height: 1.6, color: context.themeTextDark),
                ),
                const SizedBox(height: 24),
                if (item.route.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        context.push(item.route);
                      },
                      icon: Icon(item.route.startsWith('/chat') ? Icons.chat_bubble_rounded : Icons.receipt_long_rounded, size: 18),
                      label: Text(item.route.startsWith('/chat') ? 'Open chat' : 'View orders', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextLight)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = item.title;
    final body = item.body;
    final isRead = item.read;
    final time = item.createdAt;
    final orderNo = item.orderNumber;
    final route = item.route;
    final kind = _kindFor(item);

    final now = DateTime.now();
    String timeText = '';
    if (time != null) {
      final diff = now.difference(time);
      if (diff.inMinutes < 1) {
        timeText = 'Now';
      } else if (diff.inHours < 1) {
        timeText = '${diff.inMinutes}m';
      } else if (diff.inHours < 24) {
        timeText = '${diff.inHours}h';
      } else {
        timeText = DateFormat('d MMM').format(time);
      }
    }

    final meta = [if (orderNo.isNotEmpty) 'Order $orderNo', if (timeText.isNotEmpty) timeText].join(' · ');

    // One compact row. Unread = tinted, bold and a dot; read = plain and quiet.
    // Tap goes straight to where you act (the order chat); press and hold shows the full text.
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isRead ? Colors.transparent : kind.color.withValues(alpha: context.isDarkMode ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (!isRead) item.markRead();
            if (route.isNotEmpty) {
              context.push(route);
            } else {
              _showDetails(context, kind);
            }
          },
          onLongPress: () {
            HapticFeedback.selectionClick();
            if (!isRead) item.markRead();
            _showDetails(context, kind);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: kind.color.withValues(alpha: isRead ? 0.10 : 0.20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(kind.icon, color: isRead ? kind.color.withValues(alpha: 0.7) : kind.color, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                          color: isRead ? context.themeTextLight : context.themeTextDark,
                        ),
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
                      ],
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(meta,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: context.themeTextLight.withValues(alpha: 0.8),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          )),
                      ],
                    ],
                  ),
                ),
                if (!isRead)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Container(width: 9, height: 9, decoration: BoxDecoration(color: kind.color, shape: BoxShape.circle)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
