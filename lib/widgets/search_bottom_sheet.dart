import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/gig_model.dart';
import '../theme.dart';

class SearchBottomSheet extends StatefulWidget {
  final List<GigModel> gigs;
  const SearchBottomSheet({super.key, required this.gigs});

  @override
  State<SearchBottomSheet> createState() => _SearchBottomSheetState();
}

class _SearchBottomSheetState extends State<SearchBottomSheet> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).autofocus(FocusNode());
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.gigs
        : widget.gigs
            .where((g) =>
                g.title.toLowerCase().contains(_query.toLowerCase()) ||
                g.description.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.themeSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 12, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Search Input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  style: GoogleFonts.inter(color: context.themeTextDark),
                  onChanged: (val) => setState(() => _query = val),
                  decoration: InputDecoration(
                    hintText: 'Search for any service...',
                    hintStyle: GoogleFonts.inter(color: context.themeTextLight),
                    prefixIcon: Icon(Icons.search_rounded, color: context.themeTextLight),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded, color: context.themeTextLight),
                            onPressed: () {
                              _ctrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: context.themeBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Results
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No services found.',
                          style: GoogleFonts.inter(color: context.themeTextLight),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final gig = filtered[index];
                          final price = gig.packages.isNotEmpty ? gig.packages.first.price : gig.basePrice;
                          
                          return ListTile(
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(gig.imageUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            title: Text(
                              gig.title,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700,
                                color: context.themeTextDark,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '\$${price.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(color: AppTheme.primary, fontWeight: FontWeight.bold),
                            ),
                            onTap: () {
                              Navigator.pop(context); // close sheet
                              final slug = gig.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
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
            ],
          ),
        );
      },
    );
  }
}
