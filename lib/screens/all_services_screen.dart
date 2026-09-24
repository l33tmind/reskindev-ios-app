import '../widgets/shimmer_gig_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/gig_card.dart';
import '../providers/gig_provider.dart';
import '../models/gig_model.dart';
import 'package:go_router/go_router.dart';

class AllServicesScreen extends StatefulWidget {
  final String? initialCategory;
  final bool autoFocusSearch;
  const AllServicesScreen({super.key, this.initialCategory, this.autoFocusSearch = false});

  @override
  State<AllServicesScreen> createState() => _AllServicesScreenState();
}

class _AllServicesScreenState extends State<AllServicesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    if (widget.autoFocusSearch) {
      Future.delayed(const Duration(milliseconds: 100), () => _searchFocus.requestFocus());
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gigProv = context.watch<GigProvider>();
    final allGigs = gigProv.gigs;

    final categories = gigProv.categories.isNotEmpty 
        ? gigProv.categories 
        : allGigs.map((g) => g.category).toSet().toList()..removeWhere((c) => c.isEmpty);
    
    final gigs = allGigs.where((g) {
            final searchLower = _searchQuery.toLowerCase();
      final matchTitle = g.title.toLowerCase().contains(searchLower);
      final matchCategory = g.category.toLowerCase().contains(searchLower);
      final matchKeywords = g.keywords.any((k) => k.toLowerCase().contains(searchLower));
      final matchesSearch = searchLower.isEmpty || matchTitle || matchCategory || matchKeywords;
      final matchesCategory = _selectedCategory == null || g.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        backgroundColor: context.themeSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: context.themeTextDark, size: 20),
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(
          'All Services',
          style: GoogleFonts.outfit(
            color: context.themeTextDark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.inter(color: context.themeTextDark),
              decoration: InputDecoration(
                hintText: 'Search services...',
                prefixIcon: Icon(Icons.search, color: context.themeTextLight),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: context.themeTextLight),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          if (categories.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length + 1,
                itemBuilder: (context, index) {
                  final isAll = index == 0;
                  final categoryName = isAll ? 'All' : categories[index - 1];
                  final isSelected = isAll ? _selectedCategory == null : _selectedCategory == categoryName;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: ChoiceChip(
                      label: Text(categoryName),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = isAll ? null : categoryName;
                        });
                      },
                      selectedColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : context.themeTextDark,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: context.themeSurface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      side: BorderSide(
                        color: isSelected ? AppTheme.primary : context.themeBorder,
                      ),
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<GigProvider>().refresh(),
              color: AppTheme.primary,
              child: gigProv.loading
                  ? GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 220,
                      ),
                      itemCount: 6,
                      itemBuilder: (_, __) => const ShimmerGigCard(),
                    )
                  : gigs.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                            _buildEmptyState(context),
                          ],
                        )
                      : GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            mainAxisExtent: 220,
                          ),
                          itemCount: gigs.length,
                          itemBuilder: (context, index) {
                            final gig = gigs[index];
                            final slug = gig.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
                            return GigCard(
                              gig: gig,
                              onTap: () {
                                if (kIsWeb) {
                                  context.go('/gig/${gig.id}/$slug');
                                } else {
                                  context.push('/gig/${gig.id}/$slug');
                                }
                              },
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: context.themeBorder),
          const SizedBox(height: 16),
          Text(
            'No services found',
            style: GoogleFonts.inter(fontSize: 18, color: context.themeTextLight),
          ),
        ],
      ),
    );
  }
}

// Copy of _GigCard with fix for overflow
