import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/page_provider.dart';
import '../models/page_model.dart';
import '../theme.dart';

class DynamicPageScreen extends StatelessWidget {
  final String pageIdOrSlug;

  const DynamicPageScreen({super.key, required this.pageIdOrSlug});

  @override
  Widget build(BuildContext context) {
    final pageProvider = context.watch<PageProvider>();
    if (pageProvider.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator.adaptive()));
    }
    
    // Find page by id or slug
    final page = pageProvider.pages.cast<PageModel?>().firstWhere(
      (p) => p?.id == pageIdOrSlug || p?.slug == pageIdOrSlug,
      orElse: () => null,
    );
    
    if (page == null) {
      return const Scaffold(body: Center(child: Text('Page not found')));
    }

    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        title: Text(page.title, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.themeTextDark)),
        backgroundColor: context.themeSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: context.themeTextDark),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 800 ? 100 : 20,
          vertical: 40,
        ),
        child: Container(
          padding: EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: context.themeSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.themeBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                page.title,
                style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: context.themeTextDark),
              ),
              const SizedBox(height: 24),
              Divider(color: context.themeBorder),
              const SizedBox(height: 24),
              HtmlWidget(
                page.content,
                textStyle: GoogleFonts.inter(fontSize: 16, color: context.themeTextLight, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
