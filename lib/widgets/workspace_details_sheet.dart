import '../services/invoice_number.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models/order_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// "Details" from the order chat: everything about the order, to read.
/// It has no buttons on purpose: the actions live in one place, the panel at the top of the chat.
class WorkspaceDetailsSheet extends StatelessWidget {
  final String orderId;
  final String chatId;

  const WorkspaceDetailsSheet({
    super.key,
    required this.orderId,
    required this.chatId,
  });

  static String _money(num v) => '\$${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)}';
  static String _date(DateTime? d) => d == null ? '' : DateFormat('d MMM yyyy, HH:mm').format(d);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: context.themeBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final order = OrderModel.fromFirestore(snapshot.data!);
        final review = order.buyerReview;
        // Custom offers carry the seller's list of what's included
        final raw = snapshot.data!.data() as Map<String, dynamic>? ?? const {};
        final included = raw['offerFeatures'] is List ? List<String>.from((raw['offerFeatures'] as List).map((e) => '$e')) : const <String>[];

        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            color: context.themeBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: context.themeBorder, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Text(order.gigTitle,
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: order.statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(order.statusLabel,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: order.statusColor)),
                      ),
                      const Spacer(),
                      Text(_money(order.price),
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Section(children: [
                    _Row('Order', orderNumber(order.id)),
                    if (order.invoiceNumber.isNotEmpty) _Row('Invoice', invoiceNo(order.invoiceNumber)),
                    _Row('Package', order.packageName),
                    _Row('Delivery time', '${order.deliveryDays} day${order.deliveryDays == 1 ? '' : 's'}'),
                    _Row('Placed', _date(order.createdAt)),
                    if (order.deliveredAt != null) _Row('Delivered', _date(order.deliveredAt)),
                    if (order.completedAt != null && order.status == 'completed') _Row('Completed', _date(order.completedAt)),
                  ]),
                  if (included.isNotEmpty) _IncludedBlock(items: included),
                  if (order.projectDetails.isNotEmpty) _TextBlock('Requirements', order.projectDetails),
                  if (order.deliveryNote.isNotEmpty) _TextBlock('Delivery note', order.deliveryNote),
                  if (order.revisionNote.isNotEmpty && order.status == 'revision') _TextBlock('Changes requested', order.revisionNote),
                  if (review != null)
                    _TextBlock(
                      'Buyer review  ${'★' * ((review['rating'] as num?)?.round() ?? 5)}',
                      (review['comment'] ?? '').toString().isEmpty ? 'No comment' : review['comment'].toString(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final List<Widget> children;
  const _Section({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.themeBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13.5, color: context.themeTextLight)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.themeTextDark)),
          ),
        ],
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  final String label;
  final String text;
  const _TextBlock(this.label, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.themeTextLight)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.themeSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.themeBorder),
            ),
            child: SelectableText(text,
              style: GoogleFonts.inter(fontSize: 14, height: 1.4, color: context.themeTextDark)),
          ),
        ],
      ),
    );
  }
}

class _IncludedBlock extends StatelessWidget {
  final List<String> items;
  const _IncludedBlock({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("WHAT'S INCLUDED",
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.themeTextLight)),
          const SizedBox(height: 8),
          for (final f in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(f, style: GoogleFonts.inter(fontSize: 14, color: context.themeTextDark))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
