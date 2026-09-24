import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

class IosAppShowcaseSection extends StatefulWidget {
  final bool isMobile;
  const IosAppShowcaseSection({super.key, this.isMobile = false});

  @override
  State<IosAppShowcaseSection> createState() => _IosAppShowcaseSectionState();
}

class _IosAppShowcaseSectionState extends State<IosAppShowcaseSection> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoSlideTimer;

  static const String appStoreUrl = 'https://apps.apple.com/us/app/reskindev/id6802118085';

  final List<String> _screenshots = [
    'https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/ea/e1/a8/eae1a8d7-6744-eb5a-2c04-78e1a1442aee/1.png/600x0w.webp',
    'https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/fb/a0/83/fba083e5-f094-cd7c-c342-2510189aae3e/2.png/600x0w.webp',
    'https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/41/89/c7/4189c75f-00b0-909d-dfce-3dbcc9da045d/3.png/600x0w.webp',
    'https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/68/6c/f6/686cf62a-ce9a-8a43-74c3-f2541b7b4742/4.png/600x0w.webp',
  ];

  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );
  }

  void _startTimer() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        int nextPage = (_currentPage + 1) % _screenshots.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _openAppStore() async {
    final uri = Uri.parse(appStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = !widget.isMobile && screenWidth >= 980;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: isDesktop ? 40 : 16,
            vertical: isDesktop ? 40 : 24,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F172A), // Slate 900
                Color(0xFF064E3B), // Deep Emerald
                Color(0xFF0B192C), // Tech Dark Blue
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF064E3B).withValues(alpha: 0.35),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              children: [
                // Background decorative glow shapes
                Positioned(
                  top: -80,
                  left: -80,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -60,
                  right: -60,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 56 : 24,
                    vertical: isDesktop ? 60 : 36,
                  ),
                  child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Column: Details & CTA
        Expanded(
          flex: 6,
          child: _buildInfoContent(isDesktop: true),
        ),
        const SizedBox(width: 48),
        // Right Column: iPhone Mockup
        Expanded(
          flex: 5,
          child: _buildAnimatedPhoneMockup(isDesktop: true),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildInfoContent(isDesktop: false),
        const SizedBox(height: 36),
        _buildAnimatedPhoneMockup(isDesktop: false),
      ],
    );
  }

  Widget _buildInfoContent({required bool isDesktop}) {
    return Column(
      crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        // Top Pill Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.apple,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'AVAILABLE ON APP STORE',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Main Headline
        Text(
          'Manage Projects & Orders\nRight From Your iPhone',
          textAlign: isDesktop ? TextAlign.start : TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: isDesktop ? 38 : 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),

        // Subtitle
        Text(
          'Download the official Reskindev iOS app. Track live project milestones, receive instant push notifications, place custom orders, and chat directly with developers anytime, anywhere.',
          textAlign: isDesktop ? TextAlign.start : TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: isDesktop ? 15 : 14,
            color: Colors.white.withValues(alpha: 0.8),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),

        // Feature Highlights Grid
        _buildFeatureBullets(isDesktop: isDesktop),
        const SizedBox(height: 36),

        // Download CTA & App Metadata
        Wrap(
          spacing: 20,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
          children: [
            _buildAppStoreButton(),
            _buildAppStatsPill(),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureBullets({required bool isDesktop}) {
    final features = [
      {'icon': Icons.bolt_rounded, 'title': 'Live Order Tracking', 'desc': 'Track status from pending to delivery in real-time'},
      {'icon': Icons.notifications_active_rounded, 'title': 'Instant Notifications', 'desc': 'Get immediate alerts when project updates occur'},
      {'icon': Icons.verified_user_rounded, 'title': 'Secure & Seamless', 'desc': 'Fast authentication & full project management'},
    ];

    return Column(
      children: features.map((f) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  f['icon'] as IconData,
                  color: AppTheme.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f['title'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      f['desc'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAppStoreButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _openAppStore,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: const Color(0xFFA6A6A6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.apple,
                color: Colors.white,
                size: 38,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Download on the',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    'App Store',
                    style: GoogleFonts.inter(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppStatsPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 18),
          const SizedBox(width: 6),
          Text(
            'iOS 15.0+ • Free',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedPhoneMockup({required bool isDesktop}) {
    final double phoneWidth = isDesktop ? 270 : 240;
    final double phoneHeight = phoneWidth * (19.5 / 9);

    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: child,
        );
      },
      child: Center(
        child: Container(
          width: phoneWidth,
          height: phoneHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF18181B), // Dark chassis
            borderRadius: BorderRadius.circular(44),
            border: Border.all(
              color: const Color(0xFF3F3F46), // Bezel edge
              width: 3.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 36,
                spreadRadius: 4,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.25),
                blurRadius: 50,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: Stack(
                children: [
                  // Screenshots PageView
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _screenshots.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      return Image.network(
                        _screenshots[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: const Color(0xFF1E293B),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primary,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFF1E293B),
                            child: const Center(
                              child: Icon(Icons.image_not_supported_rounded, color: Colors.white38),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // Dynamic Island at top
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 80,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E293B),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Carousel Dots
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_screenshots.length, (idx) {
                        final isSelected = _currentPage == idx;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isSelected ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary : Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
