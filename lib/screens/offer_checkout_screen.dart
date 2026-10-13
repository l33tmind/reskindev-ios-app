import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/chat_models.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';

/// `/offer-checkout/:chatId/:msgId`: accepting a custom offer, same steps as ordering a service —
/// contact details, project details, payment method — and the same rules as the website's
/// /checkout/custom: offline payment waits for the admin to verify it, wallet payment starts right away.
class OfferCheckoutScreen extends StatefulWidget {
  final String chatId;
  final String msgId;
  const OfferCheckoutScreen({super.key, required this.chatId, required this.msgId});

  @override
  State<OfferCheckoutScreen> createState() => _OfferCheckoutScreenState();
}

class _OfferCheckoutScreenState extends State<OfferCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _company = TextEditingController();
  final _address = TextEditingController();
  final _details = TextEditingController();
  String _payment = 'offline';
  bool _submitting = false;
  late final Future<MessageModel?> _offer = _load();

  static const _green = Color(0xFF10B981);
  static String _money(num v) => '\$${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)}';

  Future<MessageModel?> _load() async {
    final auth = context.read<ap.AuthProvider>();
    _phone.text = auth.phone ?? '';
    _company.text = auth.company ?? '';
    _address.text = auth.address ?? '';
    final doc = await FirebaseFirestore.instance
        .collection('conversations').doc(widget.chatId).collection('messages').doc(widget.msgId).get();
    if (!doc.exists) return null;
    return MessageModel.fromMap(doc.id, doc.data()!);
  }

  @override
  void dispose() {
    for (final c in [_phone, _company, _address, _details]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(MessageModel offer, double base, double fee, double total) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final auth = context.read<ap.AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final me = auth.user!;
    final db = FirebaseFirestore.instance;
    final paidByWallet = _payment == 'wallet' && auth.walletBalance >= total;
    final title = (offer.offerTitle ?? '').trim().isNotEmpty ? offer.offerTitle!.trim() : 'Custom Offer';
    final features = offer.offerFeatures;

    final orderRef = db.collection('orders').doc();
    final order = OrderModel(
      id: orderRef.id,
      gigId: 'custom',
      gigTitle: title,
      packageId: 'custom',
      packageName: 'Custom Offer',
      price: total,
      basePrice: base,
      deliveryDays: offer.offerDays ?? 3,
      userId: me.uid,
      userName: auth.displayName,
      userEmail: me.email ?? '',
      authorId: offer.senderId,
      projectDetails: _details.text.trim(),
      // Same as a service order: offline payment waits for the admin, wallet is paid already
      status: paidByWallet ? 'requirements' : 'pending_payment',
    );
    final map = order.toMap()
      ..['id'] = orderRef.id
      ..['freelancerId'] = offer.senderId
      ..['freelancerName'] = offer.senderName
      ..['serviceFee'] = fee
      ..['requirements'] = _details.text.trim()
      ..['offerFeatures'] = features
      ..['offerDescription'] = offer.offerDescription ?? ''
      ..['createdAt'] = FieldValue.serverTimestamp();
    if (_phone.text.trim().isNotEmpty) map['clientPhone'] = _phone.text.trim();
    if (_company.text.trim().isNotEmpty) map['clientCompany'] = _company.text.trim();
    if (_address.text.trim().isNotEmpty) map['clientAddress'] = _address.text.trim();

    try {
      final batch = db.batch();
      batch.set(orderRef, map);
      batch.update(db.collection('conversations').doc(widget.chatId).collection('messages').doc(widget.msgId),
        {'offerStatus': 'accepted', 'offerOrderId': orderRef.id});
      batch.update(db.collection('conversations').doc(widget.chatId),
        {'lastMessage': 'Custom offer accepted', 'updatedAt': FieldValue.serverTimestamp()});
      if (paidByWallet) batch.update(db.collection('users').doc(me.uid), {'walletBalance': FieldValue.increment(-total)});
      await batch.commit();
      if (paidByWallet) auth.refreshWallet();
      // Remember the contact details for next time, like the service order form
      auth.updateProfile(phone: _phone.text.trim(), company: _company.text.trim(), address: _address.text.trim());

      await chatProvider.sendSystemMessage(
        buyerId: me.uid,
        buyerName: auth.displayName,
        sellerId: offer.senderId,
        sellerName: offer.senderName,
        orderId: orderRef.id,
        gigTitle: title,
        actionType: paidByWallet ? 'payment_verified' : 'order_placed',
        text: paidByWallet
            ? 'Custom offer accepted and paid from wallet: ${_money(total)}.'
            : 'Custom offer accepted: ${_money(total)}. Waiting for payment confirmation.',
        price: total,
      );
      if (mounted) context.pushReplacement('/order-chat/${orderRef.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not place the order: $e'), backgroundColor: AppTheme.error));
    }
  }

  InputDecoration _input(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: context.themeTextLight),
        filled: true,
        fillColor: context.themeSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.themeBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
      );

  Widget _section(String title, String subtitle, IconData icon) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 12.5, color: context.themeTextLight)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _row(String label, String value, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: strong ? 16 : 14, fontWeight: strong ? FontWeight.w700 : FontWeight.w500, color: strong ? context.themeTextDark : context.themeTextLight)),
            Text(value, style: strong
                ? GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primary)
                : GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.themeTextDark)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();
    final feePct = context.watch<SettingsProvider>().serviceFee;
    final style = GoogleFonts.inter(fontSize: 15, color: context.themeTextDark);

    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        title: Text('Accept Offer', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.themeTextDark)),
        centerTitle: true,
        backgroundColor: context.themeSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: context.themeTextDark),
      ),
      body: FutureBuilder<MessageModel?>(
        future: _offer,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final offer = snap.data;
          if (offer == null) return Center(child: Text('This offer is no longer available.', style: GoogleFonts.inter(color: context.themeTextLight)));
          if ((offer.offerStatus ?? 'pending') != 'pending') {
            return Center(child: Text('This offer was already ${offer.offerStatus}.', style: GoogleFonts.inter(color: context.themeTextLight)));
          }
          if (_details.text.isEmpty) _details.text = (offer.offerDescription ?? '').trim();

          final base = (offer.offerPrice ?? 0).toDouble();
          final fee = double.parse((base * feePct / 100).toStringAsFixed(2));
          final total = base + fee;
          final canWallet = auth.walletBalance >= total;

          return Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // What you get
                Container(
                  decoration: BoxDecoration(
                    color: context.themeSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.themeBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [AppTheme.primary.withValues(alpha: 0.18), AppTheme.primary.withValues(alpha: 0.03)])),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CUSTOM OFFER FROM ${offer.senderName.toUpperCase()}',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppTheme.primary)),
                            const SizedBox(height: 4),
                            Text((offer.offerTitle ?? '').isNotEmpty ? offer.offerTitle! : 'Custom offer',
                              style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.w700, color: context.themeTextDark)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final f in offer.offerFeatures)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 18, color: _green),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(f, style: GoogleFonts.inter(fontSize: 14.5, color: context.themeTextDark))),
                                  ],
                                ),
                              ),
                            Row(
                              children: [
                                Icon(Icons.schedule_rounded, size: 16, color: context.themeTextLight),
                                const SizedBox(width: 6),
                                Text('${offer.offerDays ?? 3}-day delivery', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
                              ],
                            ),
                            Divider(height: 28, color: context.themeBorder),
                            _row('Offer price', _money(base)),
                            _row('Service fee (${feePct.toStringAsFixed(feePct % 1 == 0 ? 0 : 1)}%)', _money(fee)),
                            Divider(height: 20, color: context.themeBorder),
                            _row('Total', _money(total), strong: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                _section('Contact information', 'Helps the seller and us reach you', Icons.contact_phone_outlined),
                TextFormField(
                  controller: _phone,
                  style: style,
                  keyboardType: TextInputType.phone,
                  decoration: _input('Phone number', Icons.phone_outlined),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Please enter your phone number' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _company, style: style, decoration: _input('Company / brand name (optional)', Icons.business_outlined)),
                const SizedBox(height: 12),
                TextFormField(controller: _address, style: style, decoration: _input('Address (optional)', Icons.location_on_outlined)),

                _section('Project details', 'What the seller needs to know to start', Icons.assignment_outlined),
                TextFormField(
                  controller: _details,
                  style: style,
                  minLines: 3,
                  maxLines: 8,
                  decoration: _input('Requirements, links, references…', Icons.edit_note_rounded).copyWith(alignLabelWithHint: true),
                ),

                _section('Payment method', 'Your money is held safely until you approve the delivery', Icons.lock_outline_rounded),
                Container(
                  decoration: BoxDecoration(color: context.themeSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.themeBorder)),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: 'offline',
                        groupValue: _payment,
                        activeColor: AppTheme.primary,
                        onChanged: (v) => setState(() => _payment = v!),
                        title: Text('Offline payment / bank transfer', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: context.themeTextDark)),
                        subtitle: Text('Pay manually. The order starts after we verify your payment.', style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
                      ),
                      Divider(height: 1, color: context.themeBorder),
                      RadioListTile<String>(
                        value: 'wallet',
                        groupValue: _payment,
                        activeColor: AppTheme.primary,
                        onChanged: canWallet ? (v) => setState(() => _payment = v!) : null,
                        title: Text('Wallet · ${_money(auth.walletBalance)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: context.themeTextDark)),
                        subtitle: Text(canWallet ? 'Pay now. The seller can start right away.' : 'Not enough balance for this order.',
                          style: GoogleFonts.inter(fontSize: 12, color: canWallet ? context.themeTextLight : AppTheme.error)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : () => _submit(offer, base, fee, total),
                    icon: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded),
                    label: Text('Confirm order · ${_money(total)}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
