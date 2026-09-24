import "package:cached_network_image/cached_network_image.dart";

import '../widgets/shimmer_gig_card.dart';
import '../widgets/gig_card.dart';

import 'package:seo/seo.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/floating_whatsapp_button.dart';
import '../theme.dart';
import '../models/gig_model.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/gig_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/page_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/web_nav_bar.dart';
import '../widgets/ios_app_showcase.dart';

import 'my_orders_screen.dart';
import 'admin_dashboard_screen.dart';
import 'dynamic_page_screen.dart';
import 'profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Home Screen
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';
  double _maxPrice = 5000;
  String _sortBy = 'default';
  bool _showAll = false;
  final GlobalKey _servicesKey = GlobalKey();
  
  List<String> _dynamicCategories = [];

  @override
  void initState() {
    super.initState();
    _syncRatingsOneTime();
    _fetchCategories();
  }
  
  Future<void> _fetchCategories() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('admin_settings').doc('categories').get();
      if (doc.exists && doc.data()!.containsKey('list')) {
        setState(() {
          _dynamicCategories = List<String>.from(doc.data()!['list']);
        });
      }
    } catch (e) {
      debugPrint('Failed to load categories: $e');
    }
  }

  bool _hasSynced = false;
  Future<void> _syncRatingsOneTime() async {
    if (_hasSynced) return;
    _hasSynced = true;
    try {
      final servicesSnap = await FirebaseFirestore.instance.collection('services').get();
      for (var gigDoc in servicesSnap.docs) {
        final reviewsSnap = await gigDoc.reference.collection('reviews').get();
        if (reviewsSnap.docs.isNotEmpty) {
          double totalRating = 0;
          for (var rev in reviewsSnap.docs) {
            totalRating += (rev.data()['rating'] as num?)?.toDouble() ?? 5.0;
            
            // Also try to fix the order document if possible
            final orderId = rev.data()['orderId'] as String?;
            if (orderId != null) {
              await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
                'overallRating': (rev.data()['rating'] as num?)?.toDouble() ?? 5.0,
                'publicReview': rev.data()['comment'] ?? 'Great service!',
              }, SetOptions(merge: true));
            }
          }
          final avg = totalRating / reviewsSnap.docs.length;
          await gigDoc.reference.update({
            'rating': avg,
            'averageRating': avg,
            'reviewCount': reviewsSnap.docs.length,
          });
        }
      }
      debugPrint("Ratings synced successfully!");
    } catch (e) {
      debugPrint("Error syncing ratings: $e");
    }
  }

  void _scrollToServices() {
    if (_servicesKey.currentContext != null) {
      Scrollable.ensureVisible(
        _servicesKey.currentContext!,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.themeSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateBottomSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: context.themeBorder, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Filter & Sort', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                  const SizedBox(height: 24),
                  
                  Text('Max Price: \$${_maxPrice.toInt()}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextDark)),
                  Slider(
                    value: _maxPrice,
                    min: 10,
                    max: 5000,
                    divisions: 500,
                    activeColor: AppTheme.primary,
                    label: '\$${_maxPrice.toInt()}',
                    onChanged: (v) => setStateBottomSheet(() => _maxPrice = v),
                  ),
                  const SizedBox(height: 20),
                  
                  Text('Sort By', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextDark)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ChoiceChip(
                        label: Text('Default', style: GoogleFonts.inter(color: _sortBy == 'default' ? AppTheme.primary : context.themeTextDark)),
                        selected: _sortBy == 'default',
                        onSelected: (v) => setStateBottomSheet(() => _sortBy = 'default'),
                        selectedColor: AppTheme.primary.withValues(alpha: 0.1),
                        showCheckmark: false,
                      ),
                      ChoiceChip(
                        label: Text('Price: Low to High', style: GoogleFonts.inter(color: _sortBy == 'price_asc' ? AppTheme.primary : context.themeTextDark)),
                        selected: _sortBy == 'price_asc',
                        onSelected: (v) => setStateBottomSheet(() => _sortBy = 'price_asc'),
                        selectedColor: AppTheme.primary.withValues(alpha: 0.1),
                        showCheckmark: false,
                      ),
                      ChoiceChip(
                        label: Text('Price: High to Low', style: GoogleFonts.inter(color: _sortBy == 'price_desc' ? AppTheme.primary : context.themeTextDark)),
                        selected: _sortBy == 'price_desc',
                        onSelected: (v) => setStateBottomSheet(() => _sortBy = 'price_desc'),
                        selectedColor: AppTheme.primary.withValues(alpha: 0.1),
                        showCheckmark: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {}); // Apply filters to HomeScreen
                      },
                      child: Text('Apply Filters', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<ap.AuthProvider>();
    final gigProv = context.watch<GigProvider>();
    final settings = context.watch<SettingsProvider>();

    var filteredGigs = gigProv.gigs.where((g) {
      bool catMatch = _selectedCategory == 'All';
      if (!catMatch) {
        final query = _selectedCategory.toLowerCase();
        final title = g.title.toLowerCase();
        bool hasKw(String term) => g.keywords.any((k) => k.toLowerCase().contains(term));
        if (query == 'mobile apps') catMatch = title.contains('app') || hasKw('app') || hasKw('mobile');
        else if (query == 'web dev') catMatch = title.contains('web') || hasKw('web');
        else if (query == 'ui design') catMatch = title.contains('design') || title.contains('ui') || hasKw('design') || hasKw('ui');
        else if (query == 'backend') catMatch = title.contains('backend') || title.contains('server') || title.contains('database') || hasKw('backend');
        else if (query == 'wordpress') catMatch = title.contains('wordpress') || title.contains('web') || hasKw('wordpress');
        else if (query == 'seo') catMatch = title.contains('seo') || title.contains('marketing') || hasKw('seo');
        else catMatch = title.contains(query) || hasKw(query);
      }
      if (!catMatch) return false;
      if (g.basePrice > _maxPrice) return false;
      return true;
    }).toList();

    if (_sortBy == 'price_asc') {
      filteredGigs.sort((a, b) => a.basePrice.compareTo(b.basePrice));
    } else if (_sortBy == 'price_desc') {
      filteredGigs.sort((a, b) => b.basePrice.compareTo(a.basePrice));
    }

    final childLayout = kIsWeb 
        ? _buildWebLayout(context, auth, gigProv, settings, filteredGigs)
        : _buildMobileLayout(context, auth, gigProv, settings, filteredGigs.take(4).toList(), filteredGigs.length > 4);

    return Seo.head(
      tags: [
        MetaTag(name: 'title', content: 'Reskindev - Premium App Development Services'),
        MetaTag(name: 'description', content: 'Reskindev offers premium app development, web development, and digital services. Hire expert developers to bring your ideas to life.'),
        MetaTag(name: 'og:title', content: 'Reskindev - Premium App Development Services'),
        MetaTag(name: 'og:description', content: 'Professional app development services tailored to your digital needs. Get started with our expert team.'),
      ],
      child: childLayout,
    );
  }

  // ── WEB Layout (full desktop design) ──────────────────────────
  Widget _buildWebLayout(
    BuildContext context,
    ap.AuthProvider auth,
    GigProvider gigProv,
    SettingsProvider settings,
    List<GigModel> filteredGigs,
  ) {
    final pageProv = context.watch<PageProvider>();
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: WebNavBar(
          auth: auth,
          settings: settings,
          pageProv: pageProv,
          isDesktop: isDesktop,
        ),
      ),
      floatingActionButton: Consumer<SettingsProvider>(
        builder: (context, s, _) {
          if (s.whatsappNumber.trim().isEmpty) return const SizedBox.shrink();
          return FloatingWhatsAppButton(
            isGigScreen: false,
            whatsappNumber: s.whatsappNumber,
          );
        },
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _WebHeroSection(settings: settings),
            Center(
              key: _servicesKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 40 : 20,
                    vertical: 60,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.servicesTitle,
                        style: GoogleFonts.outfit(
                          fontSize: isDesktop ? 36 : 28,
                          fontWeight: FontWeight.w800,
                          color: context.themeTextDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        settings.servicesSubtitle,
                        style: GoogleFonts.inter(fontSize: 16, color: context.themeTextLight),
                      ),
                      const SizedBox(height: 48),
                      _WebSearchAndFilter(
                        gigs: gigProv.gigs,
                        isLoading: gigProv.loading,
                        showAll: _showAll,
                        onShowAllChanged: (val) => setState(() => _showAll = val),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const IosAppShowcaseSection(isMobile: false),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ── MOBILE Layout (app-style) ──────────────────────────────────
  Widget _buildMobileLayout(
    BuildContext context,
    ap.AuthProvider auth,
    GigProvider gigProv,
    SettingsProvider settings,
    List<GigModel> displayedGigs,
    bool showMoreButton,
  ) {
    // We get all gigs for the specific categories
    final allGigs = gigProv.gigs;
    
    final videoEditingGigs = allGigs.where((g) => g.category.toLowerCase().contains('video') || g.title.toLowerCase().contains('video')).take(6).toList();
    final appDevelopmentGigs = allGigs.where((g) => g.category.toLowerCase().contains('app') || g.title.toLowerCase().contains('app')).take(6).toList();
    final popularGigs = allGigs.take(4).toList();
    final dynamicCategories = gigProv.categories.isNotEmpty 
        ? gigProv.categories 
        : allGigs.map((g) => g.category).toSet().toList()..removeWhere((c) => c.isEmpty);

    return Scaffold(
      backgroundColor: context.themeBackground,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async {
            await context.read<GigProvider>().refresh();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ── Top Header ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.user != null 
                        ? 'Welcome, ${auth.user?.displayName?.split(' ').first ?? 'back'}! 👋'
                        : 'Welcome, Guest! 👋',
                      style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: context.themeTextDark, height: 1.1),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'What service are you looking for today?',
                      style: GoogleFonts.inter(fontSize: 15, color: context.themeTextLight),
                    ),
                  ],
                ),
              ),

              // ── Search Bar ──────────────────────────────────────
              Container(
                color: context.themeBackground,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: GestureDetector(
                  onTap: () {
                    context.push('/all-services?search=true');
                  },
                  child: Hero(
                    tag: 'search_bar_hero',
                    child: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        padding: const EdgeInsets.only(left: 16, right: 6, top: 6, bottom: 6),
                        decoration: BoxDecoration(
                          color: context.themeCard,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: context.themeBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: context.themeTextLight, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Search services...',
                                style: GoogleFonts.inter(color: context.themeTextLight, fontSize: 14),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Layer 1: Top Categories (Square Cards) ──────────
              _DynamicCategoriesList(categories: dynamicCategories),

              // ── Layer 2: Video Editing (Horizontal) ─────────────
              if (videoEditingGigs.isNotEmpty)
                _LargeHorizontalGigList(
                  title: 'Video Editing',
                  titleBadge: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: const Text('🔥 Trending', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  gigs: videoEditingGigs,
                ),

              // ── Layer 3: Popular Services Grid (2-Column) ────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text('Popular Services', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark)),
              ),
              
              if (gigProv.loading)
                const _SkeletonGrid()
              else if (popularGigs.isEmpty)
                const _EmptyGigs()
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: popularGigs.length,
                  itemBuilder: (context, index) => GigCard(gig: popularGigs[index]),
                ),

              if (!gigProv.loading && allGigs.length > 4)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.go('/all-services'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text(
                        'Show More Services', 
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary)
                      ),
                    ),
                  ),
                ),

              // ── Layer 4: Mobile App Dev (Horizontal Large) ───────
              if (appDevelopmentGigs.isNotEmpty)
                _LargeHorizontalGigList(
                  title: 'Mobile App Development',
                  gigs: appDevelopmentGigs,
                ),

              // ── Layer 5: Wishlist / Saved Gigs ──────────────────
              _WishlistGigsSection(allGigs: allGigs),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }



}


// ─────────────────────────────────────────────────────────────────────────────
// MOBILE APP BAR
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// HERO BANNER
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH BAR DELEGATE
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// GIG GRID SLIVER
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.themeCard,
      highlightColor: context.themeSurface,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
          mainAxisExtent: 220,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _EmptyGigs extends StatelessWidget {
  const _EmptyGigs();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: context.themeTextLight),
            const SizedBox(height: 16),
            Text('No gigs found', style: GoogleFonts.outfit(fontSize: 20, color: context.themeTextDark)),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// NEW 5-LAYER HOME SCREEN COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _DynamicCategoriesList extends StatelessWidget {
  final List<String> categories;
  
  const _DynamicCategoriesList({required this.categories});
  
  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text('Explore Categories', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark)),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              IconData catIcon = Icons.laptop_mac_rounded;
              final lowerCat = cat.toLowerCase();
              if (lowerCat.contains('design') || lowerCat.contains('art')) {
                catIcon = Icons.brush_rounded;
              } else if (lowerCat.contains('video') || lowerCat.contains('animation')) {
                catIcon = Icons.play_circle_fill_rounded;
              } else if (lowerCat.contains('app') || lowerCat.contains('mobile')) {
                catIcon = Icons.phone_iphone_rounded;
              } else if (lowerCat.contains('web')) {
                catIcon = Icons.web_rounded;
              } else if (lowerCat.contains('marketing') || lowerCat.contains('seo')) {
                catIcon = Icons.trending_up_rounded;
              }

              return GestureDetector(
                onTap: () {
                  context.go('/all-services?category=${Uri.encodeComponent(cat)}');
                },
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.themeCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.themeBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(catIcon, size: 32, color: AppTheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        cat,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.themeTextDark),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}


class _LargeHorizontalGigList extends StatelessWidget {
  final List<GigModel> gigs;
  final String title;
  final Widget? titleBadge;
  
  const _LargeHorizontalGigList({required this.gigs, required this.title, this.titleBadge});
  
  @override
  Widget build(BuildContext context) {
    if (gigs.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark)),
              if (titleBadge != null) ...[
                const SizedBox(width: 8),
                titleBadge!,
              ],
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: gigs.length,
            itemBuilder: (context, index) {
              final gig = gigs[index];
              final slug = gig.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(
                  width: 280,
                  child: GigCard(
                    gig: gig, 
                    onTap: () {
                      if (kIsWeb) context.go('/gig/${gig.id}/$slug');
                      else context.push('/gig/${gig.id}/$slug');
                    }
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WishlistGigsSection extends StatelessWidget {
  final List<GigModel> allGigs;
  
  const _WishlistGigsSection({required this.allGigs});
  
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final savedGigIds = List<String>.from(data['savedGigs'] ?? []);
        
        if (savedGigIds.isEmpty) return const SizedBox.shrink();
        
        final savedGigs = allGigs.where((g) => savedGigIds.contains(g.id)).toList();
        if (savedGigs.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text('Your Saved Services', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark)),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: savedGigs.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 220,
              ),
              itemBuilder: (context, i) {
                final gig = savedGigs[i];
                final slug = gig.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
                return GigCard(
                  gig: gig,
                  onTap: () {
                    if (kIsWeb) context.go('/gig/${gig.id}/$slug');
                    else context.push('/gig/${gig.id}/$slug');
                  },
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WEB COMPONENTS PLACEHOLDERS (Recovered)
// ─────────────────────────────────────────────────────────────────────────────
class _WebHeroSection extends StatelessWidget {
  final SettingsProvider settings;
  const _WebHeroSection({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Premium App Development',
              style: GoogleFonts.outfit(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Hire expert developers to bring your ideas to life.',
              style: GoogleFonts.inter(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _WebSearchAndFilter extends StatelessWidget {
  final List<GigModel> gigs;
  final bool isLoading;
  final bool showAll;
  final ValueChanged<bool> onShowAllChanged;

  const _WebSearchAndFilter({
    required this.gigs,
    required this.isLoading,
    required this.showAll,
    required this.onShowAllChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _SkeletonGrid();
    }
    if (gigs.isEmpty) {
      return const _EmptyGigs();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
            mainAxisExtent: 220,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: showAll ? gigs.length : (gigs.length > 8 ? 8 : gigs.length),
          itemBuilder: (context, i) {
            final gig = gigs[i];
            final slug = gig.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
            return GigCard(
              gig: gig,
              onTap: () {
                context.go('/gig/${gig.id}/$slug');
              },
            );
          },
        ),
        if (!showAll && gigs.length > 8)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Center(
              child: ElevatedButton(
                onPressed: () => onShowAllChanged(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text('Load More Services', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ],
    );
  }
}
