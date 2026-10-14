import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/chat_models.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/order_chat_nav.dart';
import '../services/pricing_rules.dart';
import '../theme.dart';

const _green = Color(0xFF10B981);

String _money(num v) => '\$${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)}';

/// Seller: build a custom offer — what you'll do, a short description, the features one by one, price and days.
/// The features become the ✓ list the buyer sees, so they can see at a glance how much they get.
Future<void> showCreateOfferSheet(BuildContext context, {required String chatId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.themeSurface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _CreateOfferSheet(chatId: chatId),
  );
}

class _CreateOfferSheet extends StatefulWidget {
  final String chatId;
  const _CreateOfferSheet({required this.chatId});

  @override
  State<_CreateOfferSheet> createState() => _CreateOfferSheetState();
}

class _CreateOfferSheetState extends State<_CreateOfferSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _feature = TextEditingController();
  final _price = TextEditingController();
  final _days = TextEditingController(text: '3');
  final _featureFocus = FocusNode();
  final _features = <String>[];
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    for (final c in [_title, _desc, _feature, _price, _days]) {
      c.dispose();
    }
    _featureFocus.dispose();
    super.dispose();
  }

  void _addFeature() {
    final f = _feature.text.trim();
    if (f.isEmpty) return;
    if (!_features.contains(f)) setState(() => _features.add(f));
    _feature.clear();
    _featureFocus.requestFocus(); // keep typing the next one
  }

  Future<void> _send() async {
    _addFeature();
    final price = num.tryParse(_price.text.trim());
    final days = int.tryParse(_days.text.trim());
    if (_title.text.trim().isEmpty) return setState(() => _error = 'Say in a few words what you will do.');
    if (price == null || price <= 0) return setState(() => _error = 'Enter a price.');
    if (days == null || days <= 0) return setState(() => _error = 'Enter the delivery time in days.');
    final problem = (await PricingRules.load()).check(price);
    if (problem != null) return setState(() => _error = problem);

    setState(() {
      _error = null;
      _sending = true;
    });
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    await context.read<ChatProvider>().sendMessage(
      chatId: widget.chatId,
      currentUserId: auth.user!.uid,
      currentUserName: auth.displayName,
      text: 'Custom offer: ${_title.text.trim()} · ${_money(price)}',
      type: 'offer',
      offerTitle: _title.text.trim(),
      offerDescription: _desc.text.trim(),
      offerFeatures: List.of(_features),
      offerPrice: price,
      offerDays: days,
    );
    if (mounted) Navigator.pop(context);
  }

  InputDecoration _input(String hint, {Widget? prefix}) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: context.themeTextLight, fontSize: 14),
        prefixIcon: prefix,
        filled: true,
        fillColor: context.themeBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.themeBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.themeBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
      );

  Widget _label(String text, [String? hint]) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Row(
          children: [
            Text(text, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.themeTextDark)),
            if (hint != null) ...[
              const SizedBox(width: 6),
              Text(hint, style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
            ],
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.inter(fontSize: 15, color: context.themeTextDark);
    final price = num.tryParse(_price.text.trim());

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.local_offer_rounded, color: AppTheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Create a custom offer',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: context.themeTextLight)),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label('What will you do?'),
                  TextField(
                    controller: _title,
                    style: style,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _input('e.g. I will build your business website'),
                  ),
                  _label('Description', '(optional)'),
                  TextField(
                    controller: _desc,
                    style: style,
                    minLines: 2,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _input('A few words about how you will do it'),
                  ),
                  _label("What's included", 'one at a time'),
                  // Added features, as the buyer will see them
                  for (final f in _features)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: _green, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(f, style: GoogleFonts.inter(fontSize: 14.5, color: context.themeTextDark))),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.close_rounded, size: 18, color: context.themeTextLight),
                            onPressed: () => setState(() => _features.remove(f)),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _feature,
                          focusNode: _featureFocus,
                          style: style,
                          textInputAction: TextInputAction.done,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _addFeature(),
                          decoration: _input(
                            _features.isEmpty ? 'e.g. Logo design' : 'Add another, e.g. Domain & hosting setup',
                            prefix: const Icon(Icons.add_task_rounded, size: 20, color: AppTheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _addFeature,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Add'),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _label('Price (USD)'),
                            TextField(
                              controller: _price,
                              style: style,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                              onChanged: (_) => setState(() {}),
                              decoration: _input('150', prefix: Icon(Icons.attach_money_rounded, size: 20, color: context.themeTextLight)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _label('Delivery (days)'),
                            TextField(
                              controller: _days,
                              style: style,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: _input('3', prefix: Icon(Icons.schedule_rounded, size: 20, color: context.themeTextLight)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: GoogleFonts.inter(color: AppTheme.error, fontSize: 13)),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(price != null && price > 0 ? 'Send offer · ${_money(price)}' : 'Send offer'),
                style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The offer in the chat. The buyer gets the whole picture — headline, description, a ✓ list of everything
/// included, price and delivery — and two clear choices: Decline (black & white) or Accept (green).
/// The seller sees the same card with the offer's status.
class CustomOfferCard extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final String chatId;
  const CustomOfferCard({super.key, required this.message, required this.isMine, required this.chatId});

  @override
  Widget build(BuildContext context) {
    final price = message.offerPrice ?? 0;
    final days = message.offerDays ?? 0;
    final status = message.offerStatus ?? 'pending';
    final title = (message.offerTitle ?? '').trim();
    final desc = (message.offerDescription ?? '').trim();
    final features = message.offerFeatures;
    final dark = context.isDarkMode;

    return Container(
      margin: EdgeInsets.fromLTRB(isMine ? 40 : 16, 8, isMine ? 16 : 40, 8),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status == 'accepted' ? _green.withValues(alpha: 0.6) : context.themeBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.25 : 0.06), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: who it's from + price
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primary.withValues(alpha: dark ? 0.22 : 0.12), AppTheme.primary.withValues(alpha: 0.02)]),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isMine ? 'YOUR CUSTOM OFFER' : 'CUSTOM OFFER FOR YOU',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppTheme.primary)),
                      const SizedBox(height: 4),
                      Text(title.isNotEmpty ? title : 'Custom offer',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, height: 1.25, color: context.themeTextDark)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(_money(price), style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: context.themeTextDark)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (desc.isNotEmpty) ...[
                  Text(desc, style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: context.themeTextDark.withValues(alpha: 0.85))),
                  const SizedBox(height: 12),
                ],
                if (features.isNotEmpty) ...[
                  Text("WHAT'S INCLUDED",
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: context.themeTextLight)),
                  const SizedBox(height: 8),
                  for (final f in features)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(Icons.check_circle_rounded, color: _green, size: 19),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(f, style: GoogleFonts.inter(fontSize: 14.5, height: 1.35, color: context.themeTextDark))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                ],
                // Delivery + revisions in one calm row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Fact(icon: Icons.schedule_rounded, text: days > 0 ? '$days-day delivery' : 'Delivery agreed in chat'),
                    if (features.isNotEmpty) _Fact(icon: Icons.inventory_2_outlined, text: '${features.length} item${features.length == 1 ? '' : 's'} included'),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          _footer(context, status),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, String status) {
    if (status == 'accepted') {
      return _StatusBar(
        icon: Icons.check_circle_rounded,
        color: _green,
        text: isMine ? 'Accepted · the order has started' : 'You accepted · the order has started',
        action: message.offerOrderId == null ? null : 'Open order',
        onAction: () async {
          final doc = await FirebaseFirestore.instance.collection('orders').doc(message.offerOrderId).get();
          if (doc.exists && context.mounted) openOrderChat(context, OrderModel.fromFirestore(doc));
        },
      );
    }
    if (status == 'declined') {
      return _StatusBar(icon: Icons.block_rounded, color: context.themeTextLight, text: isMine ? 'The buyer declined this offer' : 'You declined this offer');
    }
    if (isMine) {
      return _StatusBar(icon: Icons.hourglass_top_rounded, color: Colors.orange, text: 'Waiting for the buyer to respond');
    }
    // Buyer, pending: the two choices
    final dark = context.isDarkMode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _decline(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: dark ? Colors.white : Colors.black,
                backgroundColor: dark ? Colors.black : Colors.white,
                side: BorderSide(color: dark ? Colors.white : Colors.black, width: 1.4),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              child: const Text('Decline'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => _accept(context),
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Text('Accept · ${_money(message.offerPrice ?? 0)}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DocumentReference get _msgRef =>
      FirebaseFirestore.instance.collection('conversations').doc(chatId).collection('messages').doc(message.id);

  Future<void> _decline(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Decline this offer?'),
        content: const Text('The seller will see that you declined. You can keep chatting and ask for a new offer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Decline')),
        ],
      ),
    );
    if (ok != true) return;
    await _msgRef.update({'offerStatus': 'declined'});
    await FirebaseFirestore.instance.collection('conversations').doc(chatId).update({
      'lastMessage': 'Custom offer declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Accepting opens the checkout (contact details, project details, payment), like ordering a service
  void _accept(BuildContext context) => context.push('/offer-checkout/$chatId/${message.id}');
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Fact({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: context.themeTextDark.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: context.themeTextLight),
            const SizedBox(width: 6),
            Text(text, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.themeTextDark)),
          ],
        ),
      );
}

class _StatusBar extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const _StatusBar({required this.icon, required this.color, required this.text, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        color: color.withValues(alpha: 0.08),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.themeTextDark))),
            if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
      );
}
