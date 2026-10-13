import "package:cached_network_image/cached_network_image.dart";

import '../widgets/shimmer_gig_card.dart';
import '../widgets/gig_card.dart';
import '../widgets/gig_cover.dart';

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
import '../services/recently_viewed_service.dart';
import '../services/notification_feed.dart';
import '../services/order_chat_nav.dart';
import '../services/invoice_number.dart';
import '../models/order_model.dart';
import '../widgets/order_next_step_panel.dart';
import '../services/recommendation_service.dart';

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
    _fetchCategories();
    RecentlyViewedService.load();
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

  // Gig ratings are kept up to date by the server (Cloud Function updateGigRating, on every review write).
  // The app used to recompute and rewrite every gig and order here on each Home open, which made every
  // phone reload the whole gig list again and again.

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

  List<GigModel> _recentGigs(List<GigModel> allGigs, List<String> ids) {
    final byId = {for (final g in allGigs) g.id: g};
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
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
              // One compact row: greeting on the left, notifications on the right
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hi, ${(auth.user?.displayName ?? '').trim().isEmpty ? 'there' : auth.user!.displayName!.split(' ').first} 👋',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: context.themeTextDark, height: 1.15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'What do you need done today?',
                            style: GoogleFonts.inter(fontSize: 13.5, color: context.themeTextLight),
                          ),
                        ],
                      ),
                    ),
                    if (auth.user != null) _NotificationBell(uid: auth.user!.uid),
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

              // ── Orders waiting on this person (buyer or seller), first thing on the page ──
              if (auth.user != null) _YourTurnSection(uid: auth.user!.uid),

              // ── Layer 1: Top Categories (compact chips) ──────────
              _DynamicCategoriesList(categories: dynamicCategories),

              // ── Recently Viewed (large cards) ───────────────────
              ValueListenableBuilder<List<String>>(
                valueListenable: RecentlyViewedService.ids,
                builder: (context, ids, _) {
                  final viewed = _recentGigs(allGigs, ids);
                  return _LargeHorizontalGigList(title: 'Recently Viewed', gigs: viewed);
                },
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

              // ── Your Saved Gigs (between Video Editing and Mobile App Dev) ──
              if (auth.user != null)
                _SavedGigsSection(uid: auth.user!.uid, allGigs: allGigs),

              // ── Recommended for you (small cards), above Mobile App Development ──
              ValueListenableBuilder<List<String>>(
                valueListenable: RecentlyViewedService.ids,
                builder: (context, ids, _) => _RecommendedGigsSection(allGigs: allGigs, recentIds: ids),
              ),

              // ── Layer 4: Mobile App Dev (Horizontal Large) ───────
              if (appDevelopmentGigs.isNotEmpty)
                _LargeHorizontalGigList(
                  title: 'Mobile App Development',
                  gigs: appDevelopmentGigs,
                ),

              // ── Every other category, alternating: small row, then large row ──
              ...() {
                final used = RegExp(r'video|app', caseSensitive: false);
                final rest = dynamicCategories.where((c) => c.isNotEmpty && !used.hasMatch(c)).toList();
                final widgets = <Widget>[];
                var n = 0;
                for (final cat in rest) {
                  final inCat = allGigs.where((g) => g.category == cat).take(8).toList();
                  if (inCat.isEmpty) continue;
                  widgets.add(n.isEven
                      ? _SmallCategoryRow(
                          title: cat,
                          gigs: inCat,
                          onSeeAll: () => context.go('/all-services?category=${Uri.encodeComponent(cat)}'),
                        )
                      : _LargeHorizontalGigList(title: cat, gigs: inCat));
                  n++;
                }
                return widgets;
              }(),

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

class _NotificationBell extends StatelessWidget {
  final String uid;
  const _NotificationBell({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotif>>(
      stream: AppNotif.stream(uid),
      builder: (context, snap) {
        final count = (snap.data ?? const <AppNotif>[]).where((n) => !n.read).length;
        return GestureDetector(
          onTap: () => context.push('/notifications'),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.themeCard,
              shape: BoxShape.circle,
              border: Border.all(color: context.themeBorder),
            ),
            // Red is the color people already read as "something new for you"
            child: Badge(
              isLabelVisible: count > 0,
              label: Text(count > 9 ? '9+' : '$count', style: const TextStyle(fontWeight: FontWeight.w700)),
              backgroundColor: AppTheme.error,
              textColor: Colors.white,
              offset: const Offset(4, -4),
              child: Icon(count > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded,
                color: context.themeTextDark, size: 24),
            ),
          ),
        );
      },
    );
  }
}

/// "Your turn": orders that wait on this person right now, as buyer or seller
/// (a delivery to accept, work to deliver, a review to leave). One tap opens the order chat,
/// the one place to manage it. Hidden when nothing is waiting, so the page stays calm.
class _YourTurnSection extends StatelessWidget {
  final String uid;
  const _YourTurnSection({required this.uid});

  @override
  Widget build(BuildContext context) {
    final orders = FirebaseFirestore.instance.collection('orders');
    return StreamBuilder<QuerySnapshot>(
      stream: orders.where('userId', isEqualTo: uid).snapshots(),
      builder: (context, buying) => StreamBuilder<QuerySnapshot>(
        stream: orders.where('authorId', isEqualTo: uid).snapshots(),
        builder: (context, selling) {
          final items = <(OrderModel, OrderStepInfo)>[];
          void add(QuerySnapshot? snap, bool asSeller) {
            for (final doc in snap?.docs ?? const []) {
              final order = OrderModel.fromFirestore(doc);
              // Reviews only nudge for 15 days, like the review window itself
              if (order.status == 'completed' &&
                  (order.completedAt == null || DateTime.now().difference(order.completedAt!).inDays > 15)) continue;
              final info = describeOrderStep(order, asSeller);
              if (info.isYourTurn) items.add((order, info));
            }
          }
          add(buying.data, false);
          add(selling.data, true);
          if (items.isEmpty) return const SizedBox.shrink();

          // Most urgent first: accept/deliver before reviews, then newest
          int rank(OrderStepInfo i) => i.action == OrderStepAction.accept || i.action == OrderStepAction.deliver ? 0 : 1;
          items.sort((a, b) {
            final r = rank(a.$2).compareTo(rank(b.$2));
            return r != 0 ? r : b.$1.createdAt.compareTo(a.$1.createdAt);
          });

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(items.length == 1 ? 'Your turn' : 'Your turn · ${items.length}',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                ),
                for (final (order, info) in items.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: info.color.withValues(alpha: context.isDarkMode ? 0.14 : 0.08),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => openOrderChat(context, order),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: info.color, shape: BoxShape.circle),
                                child: Icon(info.icon, size: 16, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Say what to do, not what happened ("Rate your order", not "Order completed")
                                    Text(
                                      switch (info.action) {
                                        OrderStepAction.buyerReview => 'Rate your order',
                                        OrderStepAction.sellerReview => 'Rate your buyer',
                                        OrderStepAction.deliver => order.status == 'revision' ? 'Deliver the changes' : 'Deliver the work',
                                        OrderStepAction.accept => 'Review the delivery',
                                        _ => info.title,
                                      },
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.themeTextDark)),
                                    const SizedBox(height: 2),
                                    Text('${orderNumber(order.id)} · ${order.gigTitle}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontSize: 12.5, color: context.themeTextLight)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(color: info.color, borderRadius: BorderRadius.circular(999)),
                                child: Text(info.shortLabel ?? 'Open',
                                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (items.length > 3)
                  TextButton(
                    onPressed: () => context.go('/my-orders'),
                    child: Text('See all ${items.length} in My Orders'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DynamicCategoriesList extends StatelessWidget {
  final List<String> categories;
  
  const _DynamicCategoriesList({required this.categories});
  
  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
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

          return Material(
            color: context.themeCard,
            shape: StadiumBorder(side: BorderSide(color: context.themeBorder)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => context.go('/all-services?category=${Uri.encodeComponent(cat)}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(catIcon, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(cat, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


/// The signed-in user's saved (wishlisted) gigs as a horizontal row on the home page.
/// Hidden when the user is signed out or hasn't saved anything yet.
class _SavedGigsSection extends StatelessWidget {
  final String uid;
  final List<GigModel> allGigs;
  const _SavedGigsSection({required this.uid, required this.allGigs});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final savedIds = List<String>.from(data?['savedGigs'] ?? const []);
        if (savedIds.isEmpty) return const SizedBox.shrink();

        // Most recently saved first (arrayUnion appends), limited to gigs that still exist
        final byId = {for (final g in allGigs) g.id: g};
        final saved = savedIds.reversed.map((id) => byId[id]).whereType<GigModel>().take(10).toList();

        return _LargeHorizontalGigList(
          title: 'Your Saved Gigs',
          titleBadge: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 18),
          gigs: saved,
        );
      },
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

/// "Recommended for You": see RecommendationService for how gigs are picked.
class _RecommendedGigsSection extends StatefulWidget {
  final List<GigModel> allGigs;
  final List<String> recentIds;

  const _RecommendedGigsSection({required this.allGigs, required this.recentIds});

  @override
  State<_RecommendedGigsSection> createState() => _RecommendedGigsSectionState();
}

class _RecommendedGigsSectionState extends State<_RecommendedGigsSection> {
  Set<String> _saved = {};
  Set<String> _ordered = {};

  @override
  void initState() {
    super.initState();
    _loadTaste();
  }

  /// What the buyer saved and what they already bought
  Future<void> _loadTaste() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final user = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final saved = List<String>.from(user.data()?['savedGigs'] ?? const []);
      final orders = await FirebaseFirestore.instance.collection('orders').where('userId', isEqualTo: uid).limit(50).get();
      final ordered = orders.docs.map((d) => (d.data()['gigId'] ?? '').toString()).where((id) => id.isNotEmpty).toSet();
      if (mounted) setState(() { _saved = saved.toSet(); _ordered = ordered; });
    } catch (e) {
      debugPrint('Recommendation taste load failed: $e');
    }
  }

  String _thumb(GigModel g) {
    if (g.imageUrl.isNotEmpty) return g.imageUrl;
    if (g.images.isNotEmpty) return g.images.first;
    if (g.galleryImages.isNotEmpty) return g.galleryImages.first;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final recs = RecommendationService.recommend(
      allGigs: widget.allGigs,
      recentIds: widget.recentIds,
      savedIds: _saved,
      orderedIds: _ordered,
      myUid: FirebaseAuth.instance.currentUser?.uid,
    );
    if (recs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text('Recommended for You', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark)),
        ),
        SizedBox(
          height: 176,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: recs.length,
            itemBuilder: (context, i) => _SmallGigCard(gig: recs[i].gig, reason: recs[i].reason),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Small gig card used in the compact rows (Recommended for You and the category rows).
class _SmallGigCard extends StatelessWidget {
  final GigModel gig;
  final String? reason;
  const _SmallGigCard({required this.gig, this.reason});

  String _thumb() {
    if (gig.imageUrl.isNotEmpty) return gig.imageUrl;
    if (gig.images.isNotEmpty) return gig.images.first;
    if (gig.galleryImages.isNotEmpty) return gig.galleryImages.first;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _thumb();
    final price = gig.packages.isNotEmpty ? gig.packages.first.price : gig.basePrice;
    final slug = gig.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () {
          if (kIsWeb) {
            context.go('/gig/${gig.id}/$slug');
          } else {
            context.push('/gig/${gig.id}/$slug');
          }
        },
        child: Container(
          width: 150,
          decoration: BoxDecoration(
            color: context.themeCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.themeBorder.withValues(alpha: 0.5)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 84,
                width: double.infinity,
                child: thumb.isNotEmpty
                    ? Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => GigCover(gig: gig, showTitle: false))
                    : GigCover(gig: gig, showTitle: false),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reason != null) ...[
                      Text(
                        reason!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      gig.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: context.themeTextDark, height: 1.2),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFFB33E), size: 13),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            gig.reviewCount > 0 && gig.averageRating > 0 ? gig.averageRating.toStringAsFixed(1) : 'New',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFFFB33E)),
                          ),
                        ),
                        Text(
                          '\$${price.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: context.themeTextDark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A category as a row of small cards.
class _SmallCategoryRow extends StatelessWidget {
  final String title;
  final List<GigModel> gigs;
  final VoidCallback onSeeAll;
  const _SmallCategoryRow({required this.title, required this.gigs, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    if (gigs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Expanded(child: Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark))),
              GestureDetector(
                onTap: onSeeAll,
                child: Text('See all', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: gigs.length,
            itemBuilder: (context, i) => _SmallGigCard(gig: gigs[i]),
          ),
        ),
      ],
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
