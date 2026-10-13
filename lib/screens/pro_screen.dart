import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart' as ap;
import '../services/pro_service.dart';
import '../theme.dart';
import '../widgets/pro_badge.dart';

/// "Reskindev Pro" — benefits, plan picker, subscribe / restore, and the active subscription.
class ProScreen extends StatefulWidget {
  const ProScreen({super.key});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  String _selected = kProYearlyId;
  late final ConfettiController _confetti = ConfettiController(duration: const Duration(seconds: 3));
  bool _celebrated = false;
  ProService? _pro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pro = context.read<ProService>();
      _pro!.clearMessages();
      if (!_pro!.productsLoaded) _pro!.loadProducts();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  static const _amber = ProBadge.amber;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();
    final pro = context.watch<ProService>();
    final active = auth.isPro;

    if (pro.justActivated && active && !_celebrated) {
      _celebrated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _confetti.play());
    }

    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        title: Text('Reskindev Pro', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.themeTextDark)),
        backgroundColor: context.themeSurface,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _hero(context, active),
                    const SizedBox(height: 16),
                    if (pro.justActivated && active) ...[
                      _banner(context, Icons.celebration_rounded, AppTheme.success,
                          'Welcome to Reskindev Pro! Your PRO badge now shows next to your name.'),
                      const SizedBox(height: 12),
                    ],
                    if (pro.error != null) ...[
                      _banner(context, Icons.error_outline_rounded, AppTheme.error, pro.error!),
                      const SizedBox(height: 12),
                    ],
                    if (pro.info != null) ...[
                      _banner(context, Icons.info_outline_rounded, AppTheme.info, pro.info!),
                      const SizedBox(height: 12),
                    ],
                    if (active) ...[
                      _statusCard(context, auth),
                      const SizedBox(height: 16),
                    ],
                    _benefits(context),
                    const SizedBox(height: 20),
                    if (_canBuy(auth)) ..._planSection(context, auth, pro),
                    if (ProService.storeSupported && auth.isLoggedIn) ...[
                      const SizedBox(height: 4),
                      Center(
                        child: TextButton(
                          onPressed: pro.busy ? null : () => pro.restorePurchases(),
                          child: Text('Restore purchases',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.primary)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _smallPrint(context, pro),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 24,
              colors: const [Color(0xFFFBBF24), _amber, AppTheme.primary, Colors.white],
            ),
          ),
        ],
      ),
    );
  }

  /// Show the plan picker when not Pro, or when the current Pro came from the wallet/admin (buying extends it).
  bool _canBuy(ap.AuthProvider auth) {
    if (!auth.isPro) return true;
    final source = auth.pro?['source'];
    return source == 'wallet' || source == 'admin';
  }

  Widget _hero(BuildContext context, bool active) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F2937), Color(0xFF111827)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _amber.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: _amber.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFFFBBF24), ProBadge.amberDark]),
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 32),
              ),
              const Spacer(),
              if (active)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.success),
                    const SizedBox(width: 4),
                    Text('Active', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.success)),
                  ]),
                )
              else
                const ProBadge(fontSize: 12),
            ],
          ),
          const SizedBox(height: 16),
          Text('Reskindev Pro ⚡',
              style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            'Stand out with a PRO badge, message any seller and share photos and videos before you order.',
            style: GoogleFonts.inter(fontSize: 14.5, height: 1.45, color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _banner(BuildContext context, IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: GoogleFonts.inter(fontSize: 13.5, height: 1.4, color: context.themeTextDark)),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Widget child) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.themeBorder.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }

  Widget _statusCard(BuildContext context, ap.AuthProvider auth) {
    final p = auth.pro ?? const {};
    final plan = p['plan'] == 'yearly' ? 'Yearly' : 'Monthly';
    final source = (p['source'] ?? '').toString();
    final sourceLabel = switch (source) {
      'apple' => 'App Store',
      'google' => 'Google Play',
      'wallet' => 'Reskindev wallet',
      'admin' => 'Gift from Reskindev',
      _ => '—',
    };
    final exp = auth.proExpiresAt;
    final date = exp != null ? DateFormat('d MMM yyyy').format(exp) : '—';
    final renews = (source == 'apple' || source == 'google') && p['autoRenew'] != false;

    String? manageUrl;
    if (source == 'apple') manageUrl = 'https://apps.apple.com/account/subscriptions';
    if (source == 'google') {
      final productId = (p['productId'] ?? '').toString();
      manageUrl = productId.isNotEmpty
          ? 'https://play.google.com/store/account/subscriptions?sku=$productId&package=com.reskindevdotcom.reskindev'
          : 'https://play.google.com/store/account/subscriptions';
    }

    return _card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your subscription',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: context.themeTextDark)),
          const SizedBox(height: 12),
          _kv(context, 'Plan', plan),
          _kv(context, 'Paid with', sourceLabel),
          _kv(context, renews ? 'Renews on' : 'Ends on', date),
          if (source == 'wallet' || source == 'admin') ...[
            const SizedBox(height: 6),
            Text('Ends on $date. Buy again to extend.',
                style: GoogleFonts.inter(fontSize: 12.5, color: context.themeTextLight)),
          ],
          if (manageUrl != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(manageUrl!), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text('Manage subscription', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(k, style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
          const Spacer(),
          Text(v, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.themeTextDark)),
        ],
      ),
    );
  }

  Widget _benefits(BuildContext context) {
    Widget row(IconData icon, String title, String sub, {bool soon = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (soon ? context.themeTextLight : _amber).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: soon ? context.themeTextLight : ProBadge.amberDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(title,
                          style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                    ),
                    if (soon) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: context.themeBorder.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Coming soon',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: context.themeTextLight)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(sub, style: GoogleFonts.inter(fontSize: 12.5, height: 1.35, color: context.themeTextLight)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What you get',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: context.themeTextDark)),
          const SizedBox(height: 6),
          row(Icons.bolt_rounded, 'PRO badge', 'A gold PRO badge next to your name on your profile, gigs and chats.'),
          row(Icons.chat_bubble_outline_rounded, 'Message any seller', 'Start a direct chat with any seller, no order needed.'),
          row(Icons.perm_media_outlined, 'Photos and videos in every chat',
              'Send photos (up to 5 MB) and videos (up to 100 MB) before you pay.'),
          row(Icons.verified_outlined, 'Free identity verification', 'Get the blue tick at no extra cost.', soon: true),
          row(Icons.support_agent_rounded, 'Priority support', 'Your questions go to the front of the line.', soon: true),
        ],
      ),
    );
  }

  List<Widget> _planSection(BuildContext context, ap.AuthProvider auth, ProService pro) {
    final storeMissing = ProService.storeSupported && !pro.loadingProducts && !pro.productsLoaded;
    return [
      Text(auth.isPro ? 'Extend with a subscription' : 'Choose your plan',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: context.themeTextDark)),
      const SizedBox(height: 10),
      _planTile(context, kProYearlyId, 'Yearly', '${pro.priceFor(kProYearlyId)} / year', '2 months free', badge: 'Save 17%'),
      const SizedBox(height: 10),
      _planTile(context, kProMonthlyId, 'Monthly', '${pro.priceFor(kProMonthlyId)} / month', 'Cancel anytime'),
      if (storeMissing && kDebugMode) ...[
        const SizedBox(height: 8),
        Text('Store products not set up yet (debug) — showing default prices.',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.warning)),
      ],
      const SizedBox(height: 16),
      SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: pro.busy
              ? null
              : !auth.isLoggedIn
                  ? () => context.push('/login')
                  : !ProService.storeSupported
                      ? null
                      : () => pro.buy(_selected),
          style: ElevatedButton.styleFrom(
            backgroundColor: _amber,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _amber.withValues(alpha: 0.5),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: pro.busy
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
              : Text(
                  !auth.isLoggedIn
                      ? 'Sign in to subscribe'
                      : !ProService.storeSupported
                          ? 'Subscribe in the iOS or Android app'
                          : 'Subscribe for ${pro.priceFor(_selected)}${_selected == kProYearlyId ? '/yr' : '/mo'}',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    ];
  }

  Widget _planTile(BuildContext context, String id, String title, String price, String sub, {String? badge}) {
    final selected = _selected == id;
    return InkWell(
      onTap: () => setState(() => _selected = id),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? _amber.withValues(alpha: 0.08) : context.themeSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _amber : context.themeBorder, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? _amber : context.themeTextLight),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(title,
                        style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w700, color: context.themeTextDark)),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.success, borderRadius: BorderRadius.circular(8)),
                        child: Text(badge,
                            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(sub, style: GoogleFonts.inter(fontSize: 12.5, color: context.themeTextLight)),
                ],
              ),
            ),
            Text(price, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.themeTextDark)),
          ],
        ),
      ),
    );
  }

  Widget _smallPrint(BuildContext context, ProService pro) {
    final store = ProService.isApple ? 'Apple ID' : 'Google Play account';
    final settings = ProService.isApple ? 'App Store account settings' : 'Google Play subscriptions';
    final style = GoogleFonts.inter(fontSize: 11.5, height: 1.45, color: context.themeTextLight);
    final link = GoogleFonts.inter(
        fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.primary, decoration: TextDecoration.underline);
    return Column(
      children: [
        Text(
          'Reskindev Pro is an auto-renewing subscription: ${pro.priceFor(kProMonthlyId)} per month or '
          '${pro.priceFor(kProYearlyId)} per year. Payment is charged to your $store when you confirm the purchase. '
          'The subscription renews automatically at the same price for the same period unless it is cancelled at '
          'least 24 hours before the end of the current period; your account is charged for the renewal within the '
          '24 hours before the period ends. You can manage or cancel it any time in your $settings.',
          textAlign: TextAlign.center,
          style: style,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(onTap: () => context.push('/page/terms'), child: Text('Terms of Use', style: link)),
            Text('   ·   ', style: style),
            GestureDetector(onTap: () => context.push('/page/privacy-policy'), child: Text('Privacy Policy', style: link)),
          ],
        ),
      ],
    );
  }
}
