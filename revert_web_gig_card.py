import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

start_idx = content.find("class _WebGigCardState extends State<_WebGigCard> {")
end_idx = content.find("class _WebFooterSection extends StatelessWidget", start_idx)

if start_idx != -1 and end_idx != -1:
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
            color: context.themeCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.themeBorder.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.08 : 0.04),
                blurRadius: _isHovered ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              AspectRatio(
                aspectRatio: 16 / 9,
                child: thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: context.themeSurface),
                        errorWidget: (context, url, error) => Container(color: context.themeSurface, child: const Icon(Icons.image, color: Colors.grey)),
                      )
                    : Container(
                        color: context.themeSurface,
                        child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                      ),
              ),
              
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Author
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                            child: Text(
                              widget.gig.authorName.isNotEmpty ? widget.gig.authorName[0].toUpperCase() : 'S', 
                              style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold)
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.gig.authorName.isNotEmpty ? widget.gig.authorName : 'Verified Seller',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.themeTextDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Title
                      Text(
                        widget.gig.title,
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: context.themeTextDark, height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const Spacer(),
                      
                      Divider(height: 1, color: context.themeBorder.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      
                      // Footer (Rating, Heart, Price)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left: Rating + Heart
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFFFB33E), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                widget.gig.averageRating > 0 ? widget.gig.averageRating.toStringAsFixed(1) : 'New',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFFB33E)),
                              ),
                              if (widget.gig.reviewCount > 0)
                                Text(
                                  ' (${widget.gig.reviewCount})',
                                  style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight),
                                ),
                              const SizedBox(width: 12),
                              Builder(
                                builder: (context) {
                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user == null) {
                                    return GestureDetector(
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please login to add to wishlist')),
                                        );
                                        context.push('/login');
                                      },
                                      child: Icon(Icons.favorite_border_rounded, size: 16, color: context.themeTextLight),
                                    );
                                  }
                                  
                                  final favRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('favorites').doc(widget.gig.id);
                                  
                                  return StreamBuilder<DocumentSnapshot>(
                                    stream: favRef.snapshots(),
                                    builder: (context, snapshot) {
                                      final isFav = snapshot.hasData && snapshot.data!.exists;
                                      
                                      return GestureDetector(
                                        onTap: () async {
                                          if (isFav) {
                                            await favRef.delete();
                                          } else {
                                            await favRef.set({
                                              'gigId': widget.gig.id,
                                              'addedAt': FieldValue.serverTimestamp(),
                                            });
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Added to wishlist'), duration: Duration(seconds: 1)),
                                              );
                                            }
                                          }
                                        },
                                        child: Icon(
                                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                                          size: 16, 
                                          color: isFav ? Colors.red : context.themeTextLight,
                                        ),
                                      );
                                    },
                                  );
                                }
                              ),
                            ],
                          ),
                          
                          // Right: Price
                          Row(
                            children: [
                              Text(
                                'From ',
                                style: GoogleFonts.inter(fontSize: 10, color: context.themeTextLight, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '\\$${startingPrice.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: context.themeTextDark),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
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
