import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

# I need to find the `_WebGigCardState` class and replace its build method.
# Wait, actually `_WebGigCardState` is a Stateful widget because it handles hover.
# It has a build method that returns MouseRegion -> GestureDetector -> Container -> Column.
# I'll replace the inside of the Container.

start_idx = content.find("class _WebGigCardState extends State<_WebGigCard>")
if start_idx != -1:
    end_idx = content.find("class _WebFooterSection extends StatelessWidget", start_idx)
    if end_idx != -1:
        old_class = content[start_idx:end_idx]
        
        new_class = """class _WebGigCardState extends State<_WebGigCard> {
  bool _isHovered = false;

  String? _getYoutubeThumbnail(String? url) {
    if (url == null || url.isEmpty) return null;
    final RegExp regExp = RegExp(
        r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
        caseSensitive: false);
    final match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      final videoId = match.group(1);
      return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    }
    return null;
  }

  String _getThumbnailUrl(GigModel gig) {
    if (gig.imageUrl.isNotEmpty) return gig.imageUrl;
    if (gig.images.isNotEmpty) return gig.images.first;
    if (gig.galleryImages.isNotEmpty) return gig.galleryImages.first;
    if (gig.youtubeUrl != null && gig.youtubeUrl!.isNotEmpty) {
      final ytThumb = _getYoutubeThumbnail(gig.youtubeUrl);
      if (ytThumb != null) return ytThumb;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = _getThumbnailUrl(widget.gig);
    final startingPrice = widget.gig.packages.isNotEmpty ? widget.gig.packages.first.price : widget.gig.basePrice;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap ?? () => context.push('/gig/${widget.gig.id}', extra: widget.gig),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _isHovered ? -5 : 0, 0),
          decoration: BoxDecoration(
            color: context.themeSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: context.isDarkMode ? Colors.transparent : Colors.black.withValues(alpha: _isHovered ? 0.1 : 0.05),
                blurRadius: _isHovered ? 15 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: thumbnailUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: context.themeBorder),
                          errorWidget: (context, url, error) => Container(color: context.themeBorder),
                        )
                      : Container(color: context.themeBorder),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.gig.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: context.themeTextDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Starting at',
                      style: GoogleFonts.inter(fontSize: 11, color: context.themeTextLight),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\\$${startingPrice.toStringAsFixed(1)}',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppTheme.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_forward, size: 14, color: AppTheme.primary),
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
"""
        content = content.replace(old_class, new_class)
        with open('lib/screens/home_screen.dart', 'w') as f:
            f.write(content)
        print("Updated _WebGigCardState layout in home_screen.dart")
