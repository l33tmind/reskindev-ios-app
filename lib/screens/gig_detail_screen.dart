import 'package:share_plus/share_plus.dart';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/floating_whatsapp_button.dart';
import '../theme.dart';
import 'package:go_router/go_router.dart';
import 'package:seo/seo.dart';
import '../providers/gig_provider.dart';
import '../models/gig_model.dart';
import '../providers/auth_provider.dart' as ap;
import 'order_form_screen.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/settings_provider.dart';
import '../providers/page_provider.dart';
import '../widgets/web_nav_bar.dart';

class GigDetailScreen extends StatefulWidget {
  final String gigId;
  const GigDetailScreen({super.key, required this.gigId});

  @override
  State<GigDetailScreen> createState() => _GigDetailScreenState();




}

class _GigDetailScreenState extends State<GigDetailScreen> {
  String _selectedPackage = '';
  // Order button → Sign In button animation এর জন্য
  bool _showSignInButton = false;
  
  // Carousel state
  int _selectedMediaIndex = 0;
    double? _discountAmount;
  final TextEditingController _couponCtrl = TextEditingController();
  
  late ConfettiController _confettiController;
  bool _isAutoUnlockChecked = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _checkAutoUnlock();
  



}
  
  Future<void> _checkAutoUnlock() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('clientUid', isEqualTo: user.uid)
          .where('gigId', isEqualTo: widget.gigId)
          .where('packageName', isEqualTo: 'Premium_Gallery')
          .where('status', whereIn: ['completed', 'in_progress'])
          .get();
          
      if (snap.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
                        _isAutoUnlockChecked = true;
          });
          _triggerCelebration('Welcome back! Your Premium Gallery is unlocked.');
        



}
      



}
    } catch (e) {
      debugPrint('Error checking auto unlock: $e');
    



}
  



}

  void _triggerCelebration(String message) {
    _confettiController.play();
    showAdaptiveDialog(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        backgroundColor: context.themeSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.celebration, color: AppTheme.primary, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Congratulations!',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: context.themeTextDark,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 15, color: context.themeTextLight),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(140, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('Awesome!', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ],
      ),
    );
  



}

  @override
  void dispose() {
    _couponCtrl.dispose();
    _confettiController.dispose();
    super.dispose();
  



}

  @override
  Widget build(BuildContext context) {
    final gigProvider = context.watch<GigProvider>();
    final auth = context.watch<ap.AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final pageProv = context.watch<PageProvider>();

    if (gigProvider.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator.adaptive()));
    



}
    
    final gig = gigProvider.getById(widget.gigId);
    if (gig == null) {
      return Scaffold(
        appBar: kIsWeb 
          ? PreferredSize(
              preferredSize: Size.fromHeight(70 + MediaQuery.of(context).padding.top),
              child: WebNavBar(auth: auth, settings: settings, pageProv: pageProv, isDesktop: MediaQuery.of(context).size.width > 800),
            )
          : AppBar(title: const Text('Not Found')),
        body: const Center(child: Text('Gig not found')),
      );
    



}
    final hasPackages = gig.packages.isNotEmpty;
    if (hasPackages && _selectedPackage.isEmpty) {
      _selectedPackage = gig.packages.first.name;
    



}
    final selectedPkg = hasPackages
        ? gig.packages.firstWhere((p) => p.name == _selectedPackage, orElse: () => gig.packages.first)
        : null;

    List<String> allMedia = [];
    if (gig.youtubeUrl != null && gig.youtubeUrl!.isNotEmpty) {
      allMedia.add(gig.youtubeUrl!);
      if (gig.imageUrl.isNotEmpty && !gig.imageUrl.contains('img.youtube.com')) {
        allMedia.add(gig.imageUrl);
      }
    } else {
      if (gig.imageUrl.isNotEmpty) {
        allMedia.add(gig.imageUrl);
      }
    }
    allMedia.addAll(gig.galleryImages);

    if (_selectedMediaIndex >= allMedia.length) {
      _selectedMediaIndex = 0;
    



}

    final String descText = gig.description.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
    final String cleanDesc = descText.length > 150 ? descText.substring(0, 150) : descText;

    // Calculate correct preview image (YouTube thumbnail, gig image, or gallery image)
    String previewImageUrl = '';
    if (gig.imageUrl.isNotEmpty) {
      previewImageUrl = gig.imageUrl;
    } else if (gig.youtubeUrl != null && gig.youtubeUrl!.isNotEmpty) {
      final videoId = YoutubePlayerController.convertUrlToId(gig.youtubeUrl!);
      if (videoId != null) {
        previewImageUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
      



}
    



}
    if (previewImageUrl.isEmpty && gig.galleryImages.isNotEmpty) {
      previewImageUrl = gig.galleryImages.first;
    



}
    if (previewImageUrl.isEmpty) {
      previewImageUrl = 'https://reskindev.com/icons/Icon-512.png';
    



}

    final isMobileView = MediaQuery.of(context).size.width < 750;

    return Seo.head(
      tags: [
        MetaTag(name: 'title', content: '${gig.title} - Reskindev'),
        MetaTag(name: 'description', content: cleanDesc),
        MetaTag(name: 'og:title', content: '${gig.title} - Reskindev'),
        MetaTag(name: 'og:description', content: cleanDesc),
        MetaTag(name: 'og:url', content: 'https://reskindev.com/gig/${gig.id}'),
        MetaTag(name: 'og:type', content: 'website'),
        MetaTag(name: 'og:site_name', content: 'Reskindev'),
        if (previewImageUrl.isNotEmpty) ...[
          MetaTag(name: 'og:image', content: previewImageUrl),
          MetaTag(name: 'og:image:secure_url', content: previewImageUrl),
          MetaTag(name: 'og:image:alt', content: gig.title),
          MetaTag(name: 'twitter:card', content: 'summary_large_image'),
          MetaTag(name: 'twitter:title', content: '${gig.title} - Reskindev'),
          MetaTag(name: 'twitter:description', content: cleanDesc),
          MetaTag(name: 'twitter:image', content: previewImageUrl),
        ],
        if (gig.youtubeUrl != null && gig.youtubeUrl!.isNotEmpty) ...[
          MetaTag(name: 'og:video', content: gig.youtubeUrl!),
        ],
      ],
      child: Stack(
        children: [
          Title(
            color: AppTheme.primary,
            title: '${gig.title} - Reskindev',
            child: Scaffold(
              backgroundColor: context.themeBackground,
              appBar: kIsWeb
                  ? PreferredSize(
                      preferredSize: const Size.fromHeight(70),
                      child: WebNavBar(auth: auth, settings: settings, pageProv: pageProv, isDesktop: MediaQuery.of(context).size.width > 800),
                    )
                  : AppBar(
                    backgroundColor: context.themeSurface,
                    elevation: 0,
                    iconTheme: IconThemeData(color: context.themeTextDark),
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back, color: context.themeTextDark),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        



}
                      },
                    ),
                    actions: [
                      if (FirebaseAuth.instance.currentUser != null)
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final userData = snapshot.hasData && snapshot.data!.exists ? snapshot.data!.data() as Map<String, dynamic> : {};
                            final savedGigs = List<String>.from(userData['savedGigs'] ?? []);
                            final isFav = savedGigs.contains(gig.id);
                            
                            return IconButton(
                              icon: Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFav ? Colors.red : context.themeTextDark),
                              onPressed: () async {
                                final ref = FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(FirebaseAuth.instance.currentUser!.uid);
                                if (isFav) {
                                  await ref.update({'savedGigs': FieldValue.arrayRemove([gig.id])});
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from Wishlist')));
                                } else {
                                  await ref.update({'savedGigs': FieldValue.arrayUnion([gig.id])});
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to Wishlist!')));
                                



}
                              },
                            );
                          },
                        ),
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.share_rounded),
                          onPressed: () async {
                            final shareUrl = 'https://reskindev.com/gig/${gig.id}';
                            final box = ctx.findRenderObject() as RenderBox?;
                            try {
                              await Share.share(
                                '🌟 Check out this service: ${gig.title}\n\n$shareUrl',
                                subject: gig.title,
                                sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
                              );
                            } catch (e) {
                              debugPrint('Share error: $e');
                            



}
                          },
                        ),
                      ),
                      if (FirebaseAuth.instance.currentUser != null)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: context.themeTextDark),
                          onSelected: (val) {
                            if (val == 'report') {
                              _showReportDialog(context, gig);
                            } else if (val == 'block') {
                              _showBlockDialog(context, gig);
                            



}
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'report', child: Text('Report Service')),
                            const PopupMenuItem(value: 'block', child: Text('Block Seller')),
                          ],
                        ),
                    ],
                  ),
            bottomNavigationBar: (isMobileView && hasPackages && selectedPkg != null) ? _buildFiverrStickyBottomBar(context, gig, selectedPkg) : null,
            body: isMobileView ? _buildMobileFiverrLayout(context, gig, allMedia, selectedPkg!) : SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 750;
                      
                      final header = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (kIsWeb)
                            TextButton.icon(
                              onPressed: () => context.go('/'),
                              icon: Icon(Icons.arrow_back, size: 16),
                              label: const Text('Back to Catalog'),
                              style: TextButton.styleFrom(foregroundColor: context.themeTextLight),
                            ),
                          if (kIsWeb) const SizedBox(height: 8),
                          Semantics(
                            header: true,
                            label: gig.title,
                            child: Text(
                              gig.title,
                              style: GoogleFonts.outfit(
                                fontSize: isMobile ? 24 : 36,
                                fontWeight: FontWeight.w800,
                                color: context.themeTextDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Review gig features, previews, and select your custom package',
                            style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight),
                          ),
                          const SizedBox(height: 12),
                          if (gig.reviewCount > 0)
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  gig.averageRating > 0 ? gig.averageRating.toStringAsFixed(1) : 'Rising Talent', 
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: context.themeTextDark)
                                ),
                                const SizedBox(width: 4),
                                if (gig.reviewCount > 0)
                                  Text('(${gig.reviewCount} reviews)', style: GoogleFonts.inter(color: context.themeTextLight, fontSize: 13)),
                              ],
                            ),
                          const SizedBox(height: 20),
                        ],
                      );
                      
                      final leftColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMediaGallery(gig, allMedia, isMobile: isMobile),
                          const SizedBox(height: 28),
                          Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: context.themeSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.themeBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Service Description',
                                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: context.themeTextDark)),
                                const SizedBox(height: 16),
                                HtmlWidget(
                                  gig.description,
                                  textStyle: GoogleFonts.inter(fontSize: 14, height: 1.7, color: context.themeTextDark),
                                  customWidgetBuilder: (element) {
                                    if (element.localName == 'iframe') {
                                      final src = element.attributes['src'] ?? '';
                                      String? ytVideoId;
                                      final ytRegex = RegExp(r'(?:youtube\.com/embed/|youtu\.be/)([\w-]+)');
                                      final match = ytRegex.firstMatch(src);
                                      if (match != null) ytVideoId = match.group(1);
                                      if (ytVideoId != null) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: AspectRatio(
                                              aspectRatio: 16 / 9,
                                              child: _YoutubeVideoPlayer(videoId: ytVideoId),
                                            ),
                                          ),
                                        );
                                      



}
                                    



}
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildSellerProfile(context, gig),
                          _buildReviewsSection(context, gig),
                          const SizedBox(height: 24),
                        ],
                      );

                      // Show unlock card if locked AND a premium item is selected
                      final rightColumn = (hasPackages ? Container(
                              key: const ValueKey('package_panel'),
                              decoration: BoxDecoration(
                                color: context.themeSurface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: context.themeBorder),
                                boxShadow: [BoxShadow(color: context.isDarkMode ? Colors.transparent : Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))],
                              ),
                              child: _buildPackageSelector(context, gig, selectedPkg!),
                            ) : const SizedBox(key: ValueKey('empty_panel')));

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          header,
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: leftColumn),
                              const SizedBox(width: 40),
                              SizedBox(width: 360, child: rightColumn),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        ), // Close Title widget
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: math.pi / 2,
            maxBlastForce: 20,
            minBlastForce: 10,
            emissionFrequency: 0.05,
            numberOfParticles: 50,
            gravity: 0.2,
            colors: const [
              Colors.green, Colors.blue, Colors.pink,
              Colors.orange, Colors.purple
            ],
          ),
        ),
      ],
    ),
    );
  



}
  
  // Inline unlock card for web (shown in right panel)
  
  Widget _buildPackageSelector(BuildContext context, GigModel gig, GigPackage selectedPkg) {
    return Column(
      children: [
        Row(
          children: gig.packages.map((pkg) {
            final isSelected = pkg.name == _selectedPackage;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedPackage = pkg.name),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(
                        color: isSelected ? AppTheme.primary : context.themeBorder,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      pkg.name,
                      style: GoogleFonts.inter(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppTheme.primary : context.themeTextLight,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(selectedPkg.name, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                  Text("\$${selectedPkg.price.toStringAsFixed(2)}", style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                ],
              ),
              const SizedBox(height: 16),
              Text(selectedPkg.description, style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight, height: 1.5)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 20, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Text("${selectedPkg.deliveryDays} Days Delivery", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                ],
              ),
              const SizedBox(height: 24),
              if (gig.masterFeatures.isNotEmpty) ...[
                Text("What's Included:", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextDark)),
                const SizedBox(height: 12),
                ...List.generate(gig.masterFeatures.length, (index) {
                  final featureName = gig.masterFeatures[index];
                  final isIncluded = index < selectedPkg.featureChecks.length && selectedPkg.featureChecks[index];
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(isIncluded ? Icons.check_circle_rounded : Icons.cancel_rounded, 
                             color: isIncluded ? AppTheme.primary : AppTheme.textMuted.withValues(alpha: 0.3), size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(featureName, style: GoogleFonts.inter(color: isIncluded ? context.themeTextDark : AppTheme.textMuted))),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    context.push("/login");
                  } else {
                    context.push("/order/${gig.id}/${selectedPkg.name}");
                  



}
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text("Continue", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  



}

  Widget _buildMediaGallery(GigModel gig, List<String> allMedia, {required bool isMobile}) {
    if (allMedia.isEmpty) return const SizedBox();
    final currentMedia = allMedia[_selectedMediaIndex];
    final isYT = currentMedia.contains('youtube.com/watch') || currentMedia.contains('youtu.be/');
    final videoId = isYT ? _extractVideoId(currentMedia) : null;
    final maxResThumbUrl = videoId != null ? 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg' : currentMedia;

    // ইউটিউব বা প্রথম মিডিয়া সবসময় আনলক থাকবে
    final bool isEffectivelyLocked = false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Viewer
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.themeBorder),
            ),
            child: (isYT && !isEffectivelyLocked && videoId != null)
              ? AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _YoutubeVideoPlayer(
                    key: ValueKey(videoId),
                    videoId: videoId,
                  ),
                )
              : AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'gig_image_${gig.id}',
                        child: isEffectivelyLocked
                            ? ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                                child: Image.network(
                                  isYT ? maxResThumbUrl : currentMedia,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey)),
                                ),
                              )
                            : Image.network(
                                isYT ? maxResThumbUrl : currentMedia,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey)),
                              ),
                      ),
                     ],
                  ),
                ),
          ),
        ),
        
        // Thumbnails Row
        if (allMedia.length > 1) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: allMedia.length,
              itemBuilder: (context, index) {
                final media = allMedia[index];
                final isSelected = _selectedMediaIndex == index;
                final isThumbYT = media.contains('youtube.com/watch') || media.contains('youtu.be/');
                final videoId = isThumbYT ? _extractVideoId(media) : null;
                final thumbUrl = videoId != null ? 'https://img.youtube.com/vi/$videoId/mqdefault.jpg' : media;
                
                // থাম্বনেইল লজিক: প্রথম আইটেম লক হবে না
                final isThumbLocked = false;
                
                return GestureDetector(
                  onTap: () => setState(() => _selectedMediaIndex = index),
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : Colors.transparent,
                        width: 2.5,
                      ),
                      image: DecorationImage(
                        image: NetworkImage(thumbUrl),
                        fit: BoxFit.cover,
                        colorFilter: (!isSelected && isThumbLocked)
                            ? ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken)
                            : null,
                      ),
                    ),
                    child: Stack(
                      children: [
                        if (isThumbYT)
                          const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 32)),
                        if (isThumbLocked)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                              child: const Icon(Icons.lock, color: Colors.white, size: 18),
                            ),
                          ),
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(4)),
                            child: Text('${index + 1}', style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  



}

  String? _extractVideoId(String url) {
    if (url.contains('v=')) {
      final id = url.split('v=')[1];
      final amp = id.indexOf('&');
      return amp != -1 ? id.substring(0, amp) : id;
    } else if (url.contains('youtu.be/')) {
      final id = url.split('youtu.be/')[1];
      final qm = id.indexOf('?');
      return qm != -1 ? id.substring(0, qm) : id;
    } else if (url.contains('embed/')) {
      final id = url.split('embed/')[1];
      final qm = id.indexOf('?');
      return qm != -1 ? id.substring(0, qm) : id;
    } else if (url.contains('shorts/')) {
      final id = url.split('shorts/')[1];
      final qm = id.indexOf('?');
      return qm != -1 ? id.substring(0, qm) : id;
    } else if (url.contains('/vi/')) {
      final id = url.split('/vi/')[1];
      final slash = id.indexOf('/');
      return slash != -1 ? id.substring(0, slash) : id;
    



}
    return null;
  



}

  String _convertToEmbedUrl(String url) {
    if (url.contains('watch?v=')) {
      return url.replaceFirst('watch?v=', 'embed/');
    



}
    if (url.contains('youtu.be/')) {
      return url.replaceFirst('youtu.be/', 'youtube.com/embed/');
    



}
    return url;
  



}

  void _handleOrder(BuildContext context, GigPackage pkg) {
    final authProvider = context.read<ap.AuthProvider>();
    if (!authProvider.isLoggedIn) {
      context.push('/login');
    } else {
      context.push('/order/${widget.gigId}/${pkg.name}');
    



}
  



}

  // "Confirm Order" button
  Widget _buildConfirmButton(BuildContext context, GigPackage pkg) {
    return SizedBox(
      key: const ValueKey('confirm'),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _handleOrder(context, pkg),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          'Confirm Order (\$${pkg.price.toStringAsFixed(2)})',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  



}

  // "Sign In with Google" button — animated হয়ে আসে
  Widget _buildSignInButton() {
    return Column(
      key: const ValueKey('signin'),
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              context.read<ap.AuthProvider>().signInWithGoogle();
            },
            icon: Icon(Icons.login_rounded, size: 20),
            label: Text(
              'Sign In with Google',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.themeSurface,
              foregroundColor: context.themeTextDark,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.primary, width: 2),
              ),
              elevation: 0,
            ),
          ),
        ),
        if (!kIsWeb && Platform.isIOS) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<ap.AuthProvider>().signInWithApple();
              },
              icon: Icon(Icons.apple, size: 20),
              label: Text(
                'Sign In with Apple',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        // "Cancel" link to go back to order button
        GestureDetector(
          onTap: () => setState(() => _showSignInButton = false),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: context.themeTextLight,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  



}




  Widget _buildFiverrStickyBottomBar(BuildContext context, GigModel gig, GigPackage pkg) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.themeSurface,
          boxShadow: [
            BoxShadow(color: context.isDarkMode ? Colors.transparent : Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
          ],
        ),
        child: Row(
          children: [
            InkWell(
              onTap: () {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  context.push("/login");
                } else if (user.uid != gig.authorId) {
                  context.push('/chat/new', extra: {
                    'targetUserId': gig.authorId,
                    'targetUserName': gig.authorName.isNotEmpty ? gig.authorName : 'Verified Seller',
                    'targetUserAvatar': '', // Fallback if no avatar
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You cannot message yourself.')),
                  );
                



}
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: context.themeBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildConfirmButton(context, pkg)),
          ],
        ),
      ),
    );
  



}

  Widget _buildMobileFiverrLayout(BuildContext context, GigModel gig, List<String> allMedia, GigPackage selectedPkg) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 250,
                width: double.infinity,
                child: allMedia.isEmpty
                    ? Container(color: Colors.grey[200])
                    : (allMedia[_selectedMediaIndex].contains('youtube.com/watch') || allMedia[_selectedMediaIndex].contains('youtu.be/'))
                        ? _YoutubeVideoPlayer(key: ValueKey(allMedia[_selectedMediaIndex]), videoId: _extractVideoId(allMedia[_selectedMediaIndex]) ?? '')
                        : Image.network(
                            allMedia[_selectedMediaIndex],
                            fit: BoxFit.cover,
                          ),
              ),
              if (allMedia.length > 1)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedMediaIndex + 1} of ${allMedia.length}',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          
          if (allMedia.length > 1)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: allMedia.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedMediaIndex;
                  final mediaUrl = allMedia[index];
                  final isYT = mediaUrl.contains('youtube.com/watch') || mediaUrl.contains('youtu.be/');
                  final thumbUrl = isYT ? 'https://img.youtube.com/vi/${_extractVideoId(mediaUrl)}/0.jpg' : mediaUrl;
                  
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMediaIndex = index),
                    child: Container(
                      width: 60,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? AppTheme.primary : Colors.transparent, width: 2),
                        image: DecorationImage(
                          image: NetworkImage(thumbUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: isYT ? const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 20)) : null,
                    ),
                  );
                },
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<DocumentSnapshot?>(
                  future: gig.authorId.isNotEmpty ? FirebaseFirestore.instance.collection('users').doc(gig.authorId).get() : Future.value(null),
                  builder: (context, snapshot) {
                    String name = gig.authorName.isNotEmpty ? gig.authorName : 'Verified Seller';
                    String photoUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0D8ABC&color=fff';
                    
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      final pName = data['name'] ?? data['displayName'];
                      if (pName != null && pName.toString().isNotEmpty) {
                        name = pName.toString();
                      



}
                      
                      final pUrl = data['photoUrl'] as String?;
                      if (pUrl != null && pUrl.isNotEmpty) {
                        photoUrl = pUrl;
                      } else {
                        photoUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0D8ABC&color=fff';
                      



}
                    



}
                    
                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: NetworkImage(photoUrl),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          name,
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: context.themeTextDark),
                        ),
                      ],
                    );
                  



}
                ),
                const SizedBox(height: 20),
                
                Text(
                  gig.title,
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: context.themeTextDark, height: 1.2),
                ),
                const SizedBox(height: 12),
                if (gig.reviewCount > 0)
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        gig.averageRating > 0 ? gig.averageRating.toStringAsFixed(1) : 'Rising Talent', 
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: context.themeTextDark)
                      ),
                      const SizedBox(width: 4),
                      if (gig.reviewCount > 0)
                        Text('(${gig.reviewCount} reviews)', style: GoogleFonts.inter(color: context.themeTextLight, fontSize: 13)),
                    ],
                  ),
                const SizedBox(height: 16),
                
                _FiverrExpandableHtml(htmlData: gig.description),
                
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                
                if (gig.packages.isNotEmpty)
                  _FiverrPricingTabs(
                    gig: gig,
                    selectedPackage: _selectedPackage,
                    onPackageSelected: (pkgName) {
                      setState(() {
                        _selectedPackage = pkgName;
                      });
                    },
                  ),
                const SizedBox(height: 24),
                _buildSellerProfile(context, gig),
                          _buildReviewsSection(context, gig),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  



}


  Widget _buildSellerProfile(BuildContext context, GigModel gig) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: context.themeCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.themeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About the Seller', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.themeTextDark)),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: Text(gig.authorName.isNotEmpty ? gig.authorName[0].toUpperCase() : 'S', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gig.authorName.isNotEmpty ? gig.authorName : 'Verified Seller', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: context.themeTextDark)),
                    const SizedBox(height: 4),
                    Text('Tap to view profile & past work', style: GoogleFonts.inter(color: AppTheme.primary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/seller-profile/${gig.authorId}', extra: {'fallbackName': gig.authorName, 'fallbackImage': gig.imageUrl}),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.themeBorder),
                    foregroundColor: context.themeTextDark,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('View Profile'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      context.push("/login");
                    } else if (user.uid != gig.authorId) {
                      context.push('/chat/new', extra: {
                        'targetUserId': gig.authorId,
                        'targetUserName': gig.authorName.isNotEmpty ? gig.authorName : 'Verified Seller',
                        'targetUserAvatar': '',
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('You cannot message yourself.')),
                      );
                    



}
                  },
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: const Text('Contact Me'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  



}

  Widget _buildReviewsSection(BuildContext context, GigModel gig) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reviews (${gig.reviewCount})', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: context.themeTextDark)),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('gigId', isEqualTo: gig.id)
              .where('status', isEqualTo: 'completed')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator.adaptive());
            



}
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Text('No reviews yet.', style: GoogleFonts.inter(color: context.themeTextLight));
            



}
            
            final reviews = snapshot.data!.docs.where((doc) {
              final text = doc.data() as Map<String, dynamic>;
              final review = text['publicReview'] as String?;
              return review != null && review.trim().isNotEmpty;
            }).toList();

            if (reviews.isEmpty) {
              return Text('No reviews yet.', style: GoogleFonts.inter(color: context.themeTextLight));
            



}

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.themeSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.themeBorder),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reviews.length,
                separatorBuilder: (_, __) => Divider(height: 32, color: context.themeBorder),
                itemBuilder: (context, index) {
                  final data = reviews[index].data() as Map<String, dynamic>;
                  final name = data['userName'] ?? 'Anonymous';
                  final rating = (data['overallRating'] as num?)?.toDouble() ?? 5.0;
                  final text = data['publicReview'] as String;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF1BCA75).withOpacity(0.1),
                            child: Text(name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF1BCA75), fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextDark)),
                          const Spacer(),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(rating.toStringAsFixed(1), style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextDark)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(text, style: GoogleFonts.inter(color: context.themeTextLight, height: 1.5)),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  



}




}

class _YoutubeVideoPlayer extends StatefulWidget {
  final String videoId;
  const _YoutubeVideoPlayer({super.key, required this.videoId});

  @override
  State<_YoutubeVideoPlayer> createState() => _YoutubeVideoPlayerState();




}

class _YoutubeVideoPlayerState extends State<_YoutubeVideoPlayer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        mute: false,
        showFullscreenButton: true,
        loop: false,
      ),
    );
  



}

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  



}

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: YoutubePlayer(
        controller: _controller,
        aspectRatio: 16 / 9,
      ),
    );
  



}




}

class _FiverrExpandableHtml extends StatelessWidget {
  final String htmlData;
  const _FiverrExpandableHtml({required this.htmlData});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: context.themeSurface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, controller) => Column(
              children: [
                Container(
                  margin: EdgeInsets.symmetric(vertical: 12),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: context.themeBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'About this Gig',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.themeTextDark,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    padding: EdgeInsets.all(20),
                    child: HtmlWidget(
                      htmlData,
                      textStyle: GoogleFonts.inter(
                        fontSize: 15,
                        height: 1.6,
                        color: context.themeTextDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: context.themeSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.themeBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'About this Gig',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: context.themeTextDark,
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  



}




}

class _FiverrPricingTabs extends StatelessWidget {
  final GigModel gig;
  final String selectedPackage;
  final Function(String) onPackageSelected;

  const _FiverrPricingTabs({required this.gig, required this.selectedPackage, required this.onPackageSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.themeBorder)),
          ),
          child: Row(
            children: gig.packages.map((pkg) {
              final isSelected = pkg.name == selectedPackage;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onPackageSelected(pkg.name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected ? context.themeTextDark : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '\$${pkg.price.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? context.themeTextDark : (context.isDarkMode ? Colors.white60 : context.themeTextLight),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        
        Builder(builder: (context) {
          final pkg = gig.packages.firstWhere((p) => p.name == selectedPackage, orElse: () => gig.packages.first);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${pkg.name} Package',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.themeTextDark),
              ),
              const SizedBox(height: 12),
              Text(
                pkg.description,
                style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: context.themeTextDark),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Delivery days', style: GoogleFonts.inter(color: context.themeTextDark)),
                  Text('${pkg.deliveryDays} Days', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextDark)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Revisions', style: GoogleFonts.inter(color: context.themeTextDark)),
                  Text('Unlimited', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextDark)),
                ],
              ),
              const SizedBox(height: 16),
              if (pkg.features.isNotEmpty || pkg.featureChecks.isNotEmpty)
                Column(
                  children: List.generate(
                    math.max(pkg.features.length, pkg.featureChecks.length),
                    (i) {
                      bool hasCheck = false;
                      String fName = '';
                      if (i < pkg.features.length) {
                        fName = pkg.features[i];
                        hasCheck = true;
                      } else if (i < pkg.featureChecks.length && i < gig.masterFeatures.length) {
                        fName = gig.masterFeatures[i];
                        hasCheck = pkg.featureChecks[i];
                      



}
                      if (!hasCheck) return const SizedBox.shrink();
                      
                      return Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.check, size: 16, color: Colors.black),
                            const SizedBox(width: 8),
                            Expanded(child: Text(fName, style: GoogleFonts.inter(color: context.themeTextDark, fontSize: 13))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        }),
      ],
    );
  



}


}
void _showReportDialog(BuildContext context, dynamic gig) {
  showDialog(
    context: context,
    builder: (context) {
      final ctrl = TextEditingController();
      bool submitting = false;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Report Service'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(hintText: 'Why are you reporting this service?'),
              maxLines: 3,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: submitting ? null : () async {
                  if (ctrl.text.isEmpty) return;
                  setState(() => submitting = true);
                  await FirebaseFirestore.instance.collection('reports').add({
                    'type': 'gig',
                    'gigId': gig.id,
                    'sellerId': gig.authorId,
                    'reason': ctrl.text,
                    'reportedBy': FirebaseAuth.instance.currentUser?.uid,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted. We will review it shortly.')));
                  }
                },
                child: submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator()) : const Text('Submit'),
              ),
            ],
          );
        },
      );
    },
  );
}

void _showBlockDialog(BuildContext context, dynamic gig) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Block Seller'),
        content: const Text('Are you sure you want to block this seller? You will no longer see their services.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                await FirebaseFirestore.instance.collection('users').doc(uid).update({
                  'blockedUsers': FieldValue.arrayUnion([gig.authorId])
                });
              }
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seller blocked.')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Block'),
          ),
        ],
      );
    },
  );
}
