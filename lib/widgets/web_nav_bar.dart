import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/settings_provider.dart';
import '../providers/page_provider.dart';

final ValueNotifier<bool> profileMenuOpen = ValueNotifier(false);

class WebNavBar extends StatelessWidget {
  final ap.AuthProvider auth;
  final SettingsProvider settings;
  final PageProvider pageProv;
  final bool isDesktop;
  
  const WebNavBar({
    super.key,
    required this.auth,
    required this.settings,
    required this.pageProv,
    required this.isDesktop,
  });

  Future<void> _handleMenuTap(BuildContext context, dynamic page) async {
    if (page.pageType == 'link') {
      final url = Uri.tryParse(page.linkUrl);
      if (url != null && await canLaunchUrl(url)) {
        await launchUrl(url, mode: page.openInNewTab ? LaunchMode.externalApplication : LaunchMode.inAppWebView);
      }
    } else {
      if (kIsWeb) {
        context.go('/${page.slug}');
      } else {
        context.push('/${page.slug}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.themeSurface,
        border: Border(bottom: BorderSide(color: context.themeBorder, width: 1)),
      ),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 16),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => context.go('/'),
              child: Row(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: isDesktop ? 40 : 32,
                    errorBuilder: (context, error, stackTrace) => RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(
                          fontSize: isDesktop ? 32 : 24,
                          fontWeight: FontWeight.w900,
                          color: context.themeTextDark,
                          letterSpacing: -1,
                        ),
                        children: const [
                          TextSpan(text: 'reskin'),
                          TextSpan(text: 'dev'),
                          TextSpan(text: '.', style: TextStyle(color: AppTheme.primary)),
                        ],
                      ),
                    ),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: 12),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: context.themeTextDark,
                          letterSpacing: -1,
                        ),
                        children: const [
                          TextSpan(text: 'reskin'),
                          TextSpan(text: 'dev'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),
          if (isDesktop) ...[
            ...pageProv.visiblePages.map((page) => Padding(
              padding: EdgeInsets.only(right: 24),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _handleMenuTap(context, page),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(page.title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: context.themeTextDark)),
                      if (page.pageType == 'link') ...[
                        const SizedBox(width: 4),
                        Icon(Icons.open_in_new, size: 13, color: context.themeTextLight),
                      ],
                    ],
                  ),
                ),
              ),
            )),
            if (auth.isAdmin) ...[
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => context.go('/admin'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.isDarkMode ? Colors.white10 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Admin', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ],
          if (auth.isLoggedIn) ...[
            IconButton(
              icon: Icon(Icons.notifications_none_rounded, color: context.themeTextDark),
              onPressed: () => context.push('/notifications'),
              tooltip: 'Notifications',
            ),
            const SizedBox(width: 16),
            _WebUserPill(auth: auth),
          ] else
            Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language, size: 16, color: context.themeTextLight),
                    const SizedBox(width: 4),
                    Text('EN', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                  ],
                ),
                const SizedBox(width: 24),
                TextButton(
                  onPressed: () => context.go('/login'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.themeTextDark,
                    textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Sign in'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.themeTextDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: Text('Join', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WebUserPill extends StatelessWidget {
  final ap.AuthProvider auth;
  const _WebUserPill({required this.auth});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showMenu(context),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: context.isDarkMode ? Colors.white10 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundImage: auth.photoUrl.isNotEmpty ? NetworkImage(auth.photoUrl) : null,
                backgroundColor: AppTheme.primary,
                child: auth.photoUrl.isEmpty ? Icon(Icons.person, size: 14, color: Colors.white) : null,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  auth.user?.displayName ?? auth.user?.email?.split('@').first ?? 'User',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.themeTextDark),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, color: context.themeTextDark, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    profileMenuOpen.value = true;
    showAdaptiveDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(ctx),
        child: Stack(
          children: [
            Positioned(
              top: 80,
              right: 40,
              child: GestureDetector(
                onTap: () {}, // Consume taps so it doesn't propagate to the barrier
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 260,
                      decoration: BoxDecoration(
                        color: context.isDarkMode 
                            ? Colors.black.withOpacity(0.6) 
                            : Colors.white.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.themeBorder.withOpacity(0.5)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                            child: Text('Account Overview', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.themeTextLight)),
                          ),
                          ListTile(
                            leading: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(10)), // Light blue
                              child: Icon(Icons.person_outline, color: Color(0xFF0284C7), size: 20),
                            ),
                            title: Text('My Profile', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: context.themeTextDark)),
                            onTap: () { Navigator.pop(ctx); context.go('/profile'); },
                          ),
                          ListTile(
                            leading: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)), // Light green
                              child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF16A34A), size: 20),
                            ),
                            title: Text('My Orders', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: context.themeTextDark)),
                            onTap: () { Navigator.pop(ctx); context.go('/my-orders'); },
                          ),
                          if (auth.isAdmin)
                            ListTile(
                              leading: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(10)), // Light purple
                                child: const Icon(Icons.grid_view_rounded, color: Color(0xFF9333EA), size: 20),
                              ),
                              title: Text('Admin Dashboard', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: context.themeTextDark)),
                              onTap: () { Navigator.pop(ctx); context.go('/admin'); },
                            ),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Color(0xFFFFEDD5), borderRadius: BorderRadius.circular(10)), // Light orange
                              child: const Icon(Icons.logout, color: Color(0xFFEA580C), size: 20),
                            ),
                            title: Text('Sign Out', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: context.themeTextDark)),
                            onTap: () { Navigator.pop(ctx); auth.signOut(); },
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: InkWell(
                                onTap: () { Navigator.pop(ctx); context.go('/profile'); }, // They can delete from profile
                                child: Text('Account Delete', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: context.themeTextDark)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    ).then((_) {
      profileMenuOpen.value = false;
    });
  }
}
