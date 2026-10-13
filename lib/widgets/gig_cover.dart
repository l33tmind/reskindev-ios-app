import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/gig_model.dart';

/// The picture for a gig that has none (or whose image fails to load): a soft gradient picked from the gig,
/// its category icon and its title, instead of a grey box with a broken-image icon.
class GigCover extends StatelessWidget {
  final GigModel gig;
  /// Small cards hide the title (it's printed under the picture anyway)
  final bool showTitle;
  const GigCover({super.key, required this.gig, this.showTitle = true});

  static const _gradients = [
    [Color(0xFF0EA5E9), Color(0xFF6366F1)],
    [Color(0xFF14B8A6), Color(0xFF0EA5E9)],
    [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    [Color(0xFFF97316), Color(0xFFEAB308)],
    [Color(0xFF10B981), Color(0xFF14B8A6)],
    [Color(0xFF6366F1), Color(0xFF8B5CF6)],
  ];

  static IconData iconFor(String category, String title) {
    final t = '$category $title'.toLowerCase();
    if (t.contains('video') || t.contains('animation') || t.contains('edit')) return Icons.movie_creation_rounded;
    if (t.contains('vision') || t.contains(' ar ') || t.contains('vr') || t.contains('3d')) return Icons.view_in_ar_rounded;
    if (t.contains('app') || t.contains('mobile') || t.contains('ios') || t.contains('android')) return Icons.phone_iphone_rounded;
    if (t.contains('web') || t.contains('site')) return Icons.language_rounded;
    if (t.contains('design') || t.contains('logo') || t.contains('art')) return Icons.palette_rounded;
    if (t.contains('marketing') || t.contains('seo') || t.contains('ads')) return Icons.trending_up_rounded;
    if (t.contains('writ') || t.contains('content')) return Icons.edit_note_rounded;
    return Icons.auto_awesome_rounded;
  }

  @override
  Widget build(BuildContext context) {
    var h = 0;
    for (final c in gig.id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final colors = _gradients[h % _gradients.length];

    return LayoutBuilder(
      builder: (context, box) {
        final small = box.maxHeight < 120;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          ),
          padding: EdgeInsets.all(small ? 10 : 20),
          child: Stack(
            children: [
              // A large faint icon in the corner gives it texture
              Positioned(
                right: -box.maxHeight * 0.12,
                bottom: -box.maxHeight * 0.18,
                child: Icon(iconFor(gig.category, gig.title), size: box.maxHeight * 0.85, color: Colors.white.withValues(alpha: 0.14)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: showTitle && !small ? MainAxisAlignment.end : MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(small ? 6 : 8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                    child: Icon(iconFor(gig.category, gig.title), color: Colors.white, size: small ? 18 : 24),
                  ),
                  if (showTitle && !small) ...[
                    const SizedBox(height: 10),
                    Text(
                      gig.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
