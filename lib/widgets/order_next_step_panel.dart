import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/order_model.dart';
import '../theme.dart';
import 'workspace_timeline_modals.dart';

/// The bar at the top of an order chat, and the one place to manage the order.
///
/// Folded (the default) it is a single line: what is happening for this person, plus a small
/// button for their next step, so the chat keeps its space. Tapping the line opens the full view:
/// what happens next, the delivery or revision note, progress, and all the buttons.
class OrderNextStepPanel extends StatefulWidget {
  final OrderModel order;
  final bool isSeller;
  final String chatId;
  final VoidCallback onDetails;

  const OrderNextStepPanel({
    super.key,
    required this.order,
    required this.isSeller,
    required this.chatId,
    required this.onDetails,
  });

  @override
  State<OrderNextStepPanel> createState() => _OrderNextStepPanelState();
}

class _OrderNextStepPanelState extends State<OrderNextStepPanel> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Debug builds run with --dart-define=ACCEPT_DEMO=true open the accept sheet for a delivered order
    // straight away (simulator screenshots of the buyer's sheet; nothing is written unless a button is tapped)
    if (kDebugMode && const bool.fromEnvironment('ACCEPT_DEMO') && widget.order.status == 'delivered') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) WorkspaceActionModals.showAcceptDelivery(context, widget.order, widget.chatId, closeSheet: false);
      });
    }
  }

  // When the order moves on (delivered, accepted, ...) fold the bar again, so the chat gets its space back
  @override
  void didUpdateWidget(covariant OrderNextStepPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.status != widget.order.status && _expanded) {
      setState(() => _expanded = false);
    }
  }

  OrderModel get order => widget.order;
  bool get isSeller => widget.isSeller;
  String get chatId => widget.chatId;

  /// 0 = waiting for payment, 1 = paid / working, 2 = delivered, 3 = completed
  int get _stage {
    switch (order.status) {
      case 'pending_payment':
        return 0;
      case 'delivered':
        return 2;
      case 'completed':
        return 3;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _stepFor(context);
    final cancelled = order.status.startsWith('cancel');

    return Material(
      color: context.themeSurface,
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.themeBorder))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The one line that is always visible
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Icon(step.icon, size: 18, color: step.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(step.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                    ),
                    if (!_expanded && step.action != null) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: step.action,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: step.color,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: const StadiumBorder(),
                            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          child: Text(step.shortLabel ?? step.actionLabel!),
                        ),
                      ),
                    ],
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.keyboard_arrow_down_rounded, color: context.themeTextLight),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Folded: progress as a hairline under the bar
            if (!_expanded) _ProgressLine(stage: _stage, cancelled: cancelled),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _expanded ? _expandedBody(context, step, cancelled) : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expandedBody(BuildContext context, _Step step, bool cancelled) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(step.subtitle, style: GoogleFonts.inter(fontSize: 13, height: 1.35, color: context.themeTextLight)),
          if (const ['requirements', 'pending', 'processing', 'in_progress', 'revision'].contains(order.status)) ...[
            const SizedBox(height: 4),
            _DueIn(deadline: (order.startedAt ?? order.createdAt).add(Duration(days: order.deliveryDays))),
          ],
          if (step.note != null && step.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: step.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (step.noteLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(step.noteLabel!.toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.themeTextLight)),
                    ),
                  Text(step.note!,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: context.themeTextDark)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          _ProgressSteps(stage: _stage, cancelled: cancelled),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(order.gigTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11.5, color: context.themeTextLight)),
              ),
              TextButton(
                onPressed: widget.onDetails,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  textStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                child: const Text('Order details  ›'),
              ),
            ],
          ),
          if (step.action != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (step.secondaryAction != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: step.secondaryAction,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.themeTextDark,
                        side: BorderSide(color: context.themeBorder),
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      child: Text(step.secondaryLabel!, maxLines: 1, softWrap: false),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: step.action,
                    icon: Icon(step.actionIcon, size: 18),
                    label: Text(step.actionLabel!, maxLines: 1, softWrap: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: step.color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  _Step _stepFor(BuildContext context) {
    final info = describeOrderStep(order, isSeller);
    VoidCallback? action;
    switch (info.action) {
      case OrderStepAction.deliver:
        action = () => WorkspaceActionModals.showDeliverWork(context, order, chatId, closeSheet: false);
      case OrderStepAction.accept:
        action = () => WorkspaceActionModals.showAcceptDelivery(context, order, chatId, closeSheet: false);
      case OrderStepAction.buyerReview:
        action = () => WorkspaceActionModals.showBuyerReview(context, order, chatId);
      case OrderStepAction.sellerReview:
        action = () => WorkspaceActionModals.showSellerReview(context, order, chatId);
      case OrderStepAction.none:
        action = null;
    }
    return _Step(info.icon, info.color, info.title, info.subtitle,
      note: info.note,
      noteLabel: info.noteLabel,
      actionLabel: info.actionLabel,
      shortLabel: info.shortLabel,
      actionIcon: info.actionIcon,
      action: action,
      secondaryLabel: info.canAskForChanges ? 'Ask for changes' : null,
      secondaryAction: info.canAskForChanges
          ? () => WorkspaceActionModals.showRevision(context, order, chatId, closeSheet: false)
          : null,
    );
  }
}

/// What the person can do next on an order
enum OrderStepAction { none, deliver, accept, buyerReview, sellerReview }

/// What an order means right now for one person (buyer or seller). Shared by the order chat bar
/// and the Home screen, so both always say the same thing.
class OrderStepInfo {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? note;
  /// Small caption over the note ("Buyer's requirements")
  final String? noteLabel;
  final OrderStepAction action;
  final String? actionLabel;
  final String? shortLabel;
  final IconData? actionIcon;
  final bool canAskForChanges;

  const OrderStepInfo(this.icon, this.color, this.title, this.subtitle, {
    this.note,
    this.noteLabel,
    this.action = OrderStepAction.none,
    this.actionLabel,
    this.shortLabel,
    this.actionIcon,
    this.canAskForChanges = false,
  });

  /// True when the order is waiting on this person, not on the other side
  bool get isYourTurn => action != OrderStepAction.none;
}

OrderStepInfo describeOrderStep(OrderModel order, bool isSeller) {
  const purple = Color(0xFF8B5CF6);
  switch (order.status) {
    case 'pending_payment':
      return isSeller
          ? const OrderStepInfo(Icons.hourglass_top_rounded, Colors.orange, 'Waiting for payment',
              "Don't start yet. We'll tell you as soon as the buyer's payment is confirmed.")
          : const OrderStepInfo(Icons.verified_user_outlined, Colors.orange, 'Confirming your payment',
              "Nothing to do right now. We'll notify you when it's confirmed and the seller can start.");
    case 'requirements':
    case 'pending':
    case 'processing':
    case 'in_progress':
      return isSeller
          ? OrderStepInfo(Icons.rocket_launch_rounded, purple, 'Your turn: deliver the work',
              'Payment is held safely. Here is what the buyer asked for. Use the chat for questions, then deliver.',
              note: order.projectDetails, noteLabel: "Buyer's requirements",
              action: OrderStepAction.deliver, actionLabel: 'Deliver Work', shortLabel: 'Deliver', actionIcon: Icons.send_rounded)
          : const OrderStepInfo(Icons.handyman_rounded, AppTheme.info, 'The seller is working on it',
              "Payment is held safely. Send any details in the chat below. You'll be notified when it's delivered.");
    case 'revision':
      return isSeller
          ? OrderStepInfo(Icons.edit_note_rounded, Colors.orange, 'The buyer asked for changes',
              'Make the changes, then deliver again.',
              note: order.revisionNote,
              action: OrderStepAction.deliver, actionLabel: 'Deliver Again', shortLabel: 'Deliver', actionIcon: Icons.send_rounded)
          : OrderStepInfo(Icons.edit_note_rounded, Colors.orange, 'Changes requested',
              "The seller is working on your changes. You'll be notified when the new delivery arrives.",
              note: order.revisionNote);
    case 'delivered':
      return isSeller
          ? const OrderStepInfo(Icons.inventory_2_rounded, purple, 'Delivered. Waiting for the buyer',
              "The buyer is reviewing your delivery. You'll be notified when they accept.")
          : OrderStepInfo(Icons.inventory_2_rounded, AppTheme.success, 'Your delivery is ready',
              'Take a look. Happy? Accept. Not quite? Asking for changes is free.',
              note: order.deliveryNote,
              action: OrderStepAction.accept, actionLabel: 'Review & Accept', shortLabel: 'Check it', actionIcon: Icons.check_circle_rounded,
              canAskForChanges: true);
    case 'completed':
      if (!isSeller && order.buyerReview == null) {
        return const OrderStepInfo(Icons.celebration_rounded, AppTheme.success, 'Order completed',
            'All done! A quick review helps other buyers.',
            action: OrderStepAction.buyerReview, actionLabel: 'Leave a Review', shortLabel: 'Review', actionIcon: Icons.star_rounded);
      }
      if (isSeller && order.sellerReview == null) {
        return const OrderStepInfo(Icons.celebration_rounded, AppTheme.success, 'Order completed',
            'Payment is released to you. Rate the buyer to see their review.',
            action: OrderStepAction.sellerReview, actionLabel: 'Rate the Buyer', shortLabel: 'Rate', actionIcon: Icons.star_rounded);
      }
      return const OrderStepInfo(Icons.celebration_rounded, AppTheme.success, 'Order completed', 'All done. Thanks for working together!');
    case 'cancelled':
      return const OrderStepInfo(Icons.cancel_outlined, AppTheme.error, 'Order cancelled', 'This order was cancelled.');
    default:
      if (order.status.startsWith('cancel_requested')) {
        return const OrderStepInfo(Icons.help_outline_rounded, AppTheme.error, 'Cancellation requested',
            'Reply here in the chat, or answer the request from My Orders.');
      }
      return OrderStepInfo(Icons.info_outline_rounded, Colors.grey, order.statusLabel, 'Tap Order details to see this order.');
  }
}

class _Step {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? note;
  final String? noteLabel;
  final String? actionLabel;
  /// The label on the small button in the folded bar ("Accept" instead of "Accept Delivery")
  final String? shortLabel;
  final IconData? actionIcon;
  final VoidCallback? action;
  final String? secondaryLabel;
  final VoidCallback? secondaryAction;

  const _Step(this.icon, this.color, this.title, this.subtitle, {
    this.note,
    this.noteLabel,
    this.actionLabel,
    this.shortLabel,
    this.actionIcon,
    this.action,
    this.secondaryLabel,
    this.secondaryAction,
  });
}

const _stepLabels = ['Paid', 'Working', 'Delivered', 'Done'];

/// Folded view: progress as a 2px line along the bottom of the bar
class _ProgressLine extends StatelessWidget {
  final int stage;
  final bool cancelled;
  const _ProgressLine({required this.stage, required this.cancelled});

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: (stage + 1) / _stepLabels.length,
      minHeight: 2,
      backgroundColor: Colors.transparent,
      color: cancelled ? AppTheme.error : AppTheme.primary,
    );
  }
}

/// Open view: Paid → Working → Delivered → Done as a 4-part bar with the current step named
class _ProgressSteps extends StatelessWidget {
  final int stage;
  final bool cancelled;
  const _ProgressSteps({required this.stage, required this.cancelled});

  @override
  Widget build(BuildContext context) {
    final active = cancelled ? AppTheme.error : AppTheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (int i = 0; i < _stepLabels.length; i++) ...[
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= stage ? active : context.themeBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < _stepLabels.length - 1) const SizedBox(width: 4),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (int i = 0; i < _stepLabels.length; i++)
              Expanded(
                child: Text(_stepLabels[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: i == stage ? FontWeight.w700 : FontWeight.w500,
                    color: i <= stage ? context.themeTextDark : context.themeTextLight,
                  )),
              ),
          ],
        ),
      ],
    );
  }
}

/// "Due in 2d 23h" (or "Late by 3h" in red). Updates once a minute: a ticking seconds counter adds stress, not information.
class _DueIn extends StatefulWidget {
  final DateTime deadline;
  const _DueIn({required this.deadline});

  @override
  State<_DueIn> createState() => _DueInState();
}

class _DueInState extends State<_DueIn> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _span(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes.clamp(1, 59)}m';
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.deadline.difference(DateTime.now());
    final late = left.isNegative;
    final color = late ? AppTheme.error : Colors.orange;
    return Row(
      children: [
        Icon(late ? Icons.warning_amber_rounded : Icons.schedule_rounded, size: 14, color: color),
        const SizedBox(width: 4),
        Text(late ? 'Late by ${_span(-left)}' : 'Due in ${_span(left)}',
          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
