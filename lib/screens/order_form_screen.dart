import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:online_platform/services/notification_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../models/gig_model.dart';
import '../providers/gig_provider.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/settings_provider.dart';
import '../providers/page_provider.dart';
import '../widgets/web_nav_bar.dart';
import '../providers/chat_provider.dart';

class OrderFormScreen extends StatefulWidget {
  final String gigId;
  final String packageName;
  const OrderFormScreen({super.key, required this.gigId, required this.packageName});

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _detailsCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _submitting = false;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<ap.AuthProvider>();
      _phoneCtrl.text = auth.phone ?? '';
      _companyCtrl.text = auth.company ?? '';
      _addressCtrl.text = auth.address ?? '';
    });
  }

  @override
  void dispose() {
    _detailsCtrl.dispose();
    _phoneCtrl.dispose();
    _companyCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final auth = context.read<ap.AuthProvider>();
    if (auth.user == null) {
      setState(() => _submitting = false);
      return;
    }

    // Save any new profile info
    final phone = _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim();
    final company = _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim();
    final address = _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim();
    if (phone != auth.phone || company != auth.company || address != auth.address) {
      await auth.updateProfile(phone: phone, company: company, address: address);
    }
    if (!mounted) return;

    final gigProvider = context.read<GigProvider>();
    final gig = gigProvider.getById(widget.gigId);
    if (gig == null) {
      setState(() => _submitting = false);
      return;
    }

    GigPackage? package;
    if (widget.packageName == 'Premium_Gallery') {
      package = GigPackage(
        name: 'Premium_Gallery',
        price: gig.galleryUnlockPrice,
        description: 'Unlock full premium gallery access.',
        deliveryDays: 1,
        featureChecks: [],
      );
    } else {
      try {
        package = gig.packages.firstWhere((p) => p.name == widget.packageName);
      } catch (_) {
        setState(() => _submitting = false);
        return;
      }
    }

    final settings = context.read<SettingsProvider>();
    final double serviceFeePct = settings.serviceFee;
    final double discountedPrice = package.price - 0; // 0 is discountAmount
    final double serviceFeeAmount = discountedPrice * (serviceFeePct / 100);
    final double finalPrice = discountedPrice + serviceFeeAmount;

    final order = OrderModel(
      gigId: gig.id,
      gigTitle: gig.title,
      packageId: package.id.isNotEmpty ? package.id : package.name.toLowerCase(),
      packageName: package.name,
      price: finalPrice, // Used as total price
      basePrice: package.price,
      discountAmount: 0,
      quantity: _quantity,
      deliveryDays: package.deliveryDays * _quantity,
      userId: auth.user!.uid,
      userName: auth.user!.displayName ?? auth.user!.email ?? '',
      userEmail: auth.user!.email ?? '',
      authorId: gig.authorId,
      projectDetails: _detailsCtrl.text.trim(),
      status: 'pending_payment',
    );

    final orderMap = order.toMap();
    // Include serviceFee in the map for backend consistency
    orderMap['serviceFee'] = serviceFeeAmount;
    
    // Add optional profile fields (only if non-null)
    if (phone != null) orderMap['clientPhone'] = phone;
    if (company != null) orderMap['clientCompany'] = company;
    if (address != null) orderMap['clientAddress'] = address;

    final docRef = await FirebaseFirestore.instance.collection('orders').add(orderMap);
    
    // Trigger system message
    try {
      if (context.mounted) {
        final chatProvider = context.read<ChatProvider>();
        await chatProvider.sendSystemMessage(
          buyerId: order.clientUid,
          buyerName: order.clientName,
          sellerId: order.authorId,
          sellerName: gig.authorName,
          orderId: docRef.id,
          gigTitle: order.gigTitle,
          actionType: 'order_placed',
          text: 'Order placed but waiting for payment confirmation. \$${order.price.toStringAsFixed(0)} for ${order.gigTitle}',
        );
      }
    } catch (e) {
      print('System message error: $e');
    }

    // Get Admin FCM Tokens and send push notifications
    try {
      final adminSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: 'mdrobiussany1225@gmail.com')
          .get();
      
      for (var doc in adminSnap.docs) {
        await NotificationService.sendAndSaveNotification(
          userId: doc.id,
          title: 'New Order Received! 🚀',
          body: '${FirebaseAuth.instance.currentUser?.displayName ?? "A client"} placed an order for ${gig.title}',
        );
      }
    } catch (e) {
      debugPrint('Error triggering admin notification: $e');
    }

    // Trigger Client Notification
    try {
      final clientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.user!.uid)
          .get();
          
      await NotificationService.sendAndSaveNotification(
        userId: auth.user!.uid,
        title: 'Order Placed Successfully! 🎉',
        body: 'Thank you for ordering ${gig.title}. We will review it and contact you shortly.',
      );
    } catch (e) {
      debugPrint('Error triggering client notification: $e');
    }

    // Trigger Email Notification (Order Placed)
    try {
      await http.post(
        Uri.parse('https://reskindev.com/php/send_email.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': order.clientEmail,
          'clientName': order.clientName,
          'orderId': order.id ?? 'New Order',
          'status': 'pending', // This should trigger the new order template
          'gigTitle': order.gigTitle,
          'packageName': order.packageName,
          'price': order.price,
          'date': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('Error sending confirmation email: $e');
    }

    setState(() => _submitting = false);
    if (!mounted) return;
    _showSuccessDialog(context, gig.title, package.name);
  }

  void _showSuccessDialog(BuildContext ctx, String gigTitle, String pkgName) {
    showAdaptiveDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: context.themeSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 48),
              ),
              const SizedBox(height: 20),
              Text('Order Placed! 🎉',
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: context.themeTextDark)),
              const SizedBox(height: 10),
              Text(
                'Your order has been submitted. We will review and contact you shortly.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight, height: 1.6),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ctx.go('/my-orders');
                  },
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: Text('View My Orders', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () { Navigator.pop(ctx); ctx.go('/'); },
                child: Text('Back to Home', style: GoogleFonts.inter(color: context.themeTextLight)),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildSignInPrompt(ap.AuthProvider auth) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.themeTextDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Premium Lock Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: context.themeSurface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: context.themeTextDark.withValues(alpha: 0.05),
                        blurRadius: 40,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: AppTheme.heroGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_outline_rounded,
                          size: 30, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Sign In to Continue',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: context.themeTextDark,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'To provide a secure experience, please sign in with your Google account to proceed with your order.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      color: context.themeTextLight,
                      height: 1.6,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 48),

                // Google Sign In Button
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: () async => await auth.signInWithGoogle(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                      shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Text('G',
                              style: TextStyle(
                                color: Color(0xFF4285F4),
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              )),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Sign in with Google',
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!kIsWeb && Platform.isIOS) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () async => await auth.signInWithApple(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.apple, size: 24),
                          const SizedBox(width: 16),
                          Text('Sign in with Apple',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: context.themeTextLight,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'Go Back',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2),
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
    final auth = context.watch<ap.AuthProvider>();
    final gigProvider = context.watch<GigProvider>();
    final settings = context.watch<SettingsProvider>();
    final pageProv = context.watch<PageProvider>();

    if (!auth.isLoggedIn) {
      return _buildSignInPrompt(auth);
    }

    if (gigProvider.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }

    final gig = gigProvider.getById(widget.gigId);
    if (gig == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: Text('Service not found')),
      );
    }

    GigPackage? package;
    if (widget.packageName == 'Premium_Gallery') {
      package = GigPackage(
        name: 'Premium_Gallery',
        price: gig.galleryUnlockPrice,
        description: 'Unlock full premium gallery access.',
        deliveryDays: 1,
        featureChecks: [],
      );
    } else {
      try {
        package = gig.packages.firstWhere((p) => p.name == widget.packageName);
      } catch (_) {
        return Scaffold(
          appBar: AppBar(leading: const BackButton()),
          body: const Center(child: Text('Package not found')),
        );
      }
    }

    if (kIsWeb) {
      return _buildWebLayout(context, auth, settings, pageProv, gig, package);
    }
    return _buildMobileLayout(context, gig, package);
  }

  Widget _buildWebLayout(
    BuildContext context, 
    ap.AuthProvider auth, 
    SettingsProvider settings, 
    PageProvider pageProv,
    GigModel gig,
    GigPackage package,
  ) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: context.themeBackground,
      body: Column(
        children: [
          WebNavBar(
            auth: auth,
            settings: settings,
            pageProv: pageProv,
            isDesktop: isDesktop,
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    child: _buildFormContent(context, gig, package),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, GigModel gig, GigPackage package) {
    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        backgroundColor: context.themeSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.themeTextDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Confirm Order',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 20, color: context.themeTextDark)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.themeBorder),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: _buildFormContent(context, gig, package),
      ),
    );
  }

  Widget _buildFormContent(BuildContext context, GigModel gig, GigPackage package) {
    final settings = context.read<SettingsProvider>();
    final double serviceFeePct = settings.serviceFee;
    final double basePackagePrice = package.price * _quantity;
    final double discountedPrice = basePackagePrice - 0; // 0 is discount
    final double serviceFeeAmount = discountedPrice * (serviceFeePct / 100);
    final double finalPrice = discountedPrice + serviceFeeAmount;
    
    final total = finalPrice;
    return Form(
      key: _formKey,
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Order Summary Card ──────────────────────────────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.themeSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.themeBorder),
                  boxShadow: [
                    BoxShadow(color: context.isDarkMode ? Colors.transparent : Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: AppTheme.heroGradient,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    package.name.replaceAll('_', ' ').toUpperCase(),
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  gig.title,
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, height: 1.3),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  package.description,
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Details row
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 16, color: context.themeTextLight),
                              const SizedBox(width: 6),
                              Text('${package.deliveryDays} Day${package.deliveryDays > 1 ? 's' : ''} Delivery',
                                  style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal',
                                  style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
                              Text('\$${discountedPrice.toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Service Fee (${serviceFeePct.toStringAsFixed(0)}%)',
                                  style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
                              Text('\$${serviceFeeAmount.toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Divider(color: context.themeBorder, height: 1),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Amount',
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: context.themeTextDark)),
                              Text('\$${total.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Payment Info Banner ─────────────────────────────
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payments_outlined, color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This is a real-world service. This is a marketplace for custom professional services. After placing your request, our support team will contact you to arrange payment securely. Once verified, the freelancer will begin working on your project.',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF92400E), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Contact Info ────────────────────────────────────
              _SectionHeader(
                title: 'Contact Information',
                subtitle: 'Helps us reach you faster',
                icon: Icons.contact_phone_outlined,
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _phoneCtrl,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _companyCtrl,
                label: 'Company / Brand Name (Optional)',
                icon: Icons.business_outlined,
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _addressCtrl,
                label: 'Address (Optional)',
                icon: Icons.location_on_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // ── Project Details ─────────────────────────────────
              _SectionHeader(
                title: 'Project Details',
                subtitle: 'Describe your needs so we can start quickly',
                icon: Icons.edit_note_rounded,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _detailsCtrl,
                maxLines: 6,
                style: GoogleFonts.inter(fontSize: 14, color: context.themeTextDark),
                decoration: InputDecoration(
                  hintText: 'Describe what you need...\n\nE.g. I need a 5-page website for my restaurant...',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
                  filled: true,
                  fillColor: context.themeSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.themeBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                // validator removed to make it optional
              ),
              const SizedBox(height: 28),

              // ── Submit Button ───────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                  ),
                  child: _submitting
                      ? const SizedBox(height: 24, width: 24,
                          child: CircularProgressIndicator(color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Confirm Order · \$${total.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 14, color: context.themeTextDark),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: context.themeTextLight),
        filled: true,
        fillColor: context.themeSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.themeBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primary, width: 2),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight),
        alignLabelWithHint: maxLines > 1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _SectionHeader({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: context.themeTextDark)),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
            ],
          ),
        ),
      ],
    );
  }
}
