new_content = """import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/gig_model.dart';
import '../theme.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GigCard extends StatelessWidget {
  final GigModel gig;
  final VoidCallback? onTap;

  const GigCard({super.key, required this.gig, this.onTap});

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
    final thumbnailUrl = _getThumbnailUrl(gig);
    final startingPrice = gig.packages.isNotEmpty ? gig.packages.first.price : gig.basePrice;

    return GestureDetector(
      onTap: onTap ?? () => context.push('/gig/${gig.id}', extra: gig),
      child: Container(
        decoration: BoxDecoration(
          color: context.themeCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.themeBorder.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
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
                            gig.authorName.isNotEmpty ? gig.authorName[0].toUpperCase() : 'S', 
                            style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold)
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            gig.authorName.isNotEmpty ? gig.authorName : 'Verified Seller',
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
                      gig.title,
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
                              gig.averageRating > 0 ? gig.averageRating.toStringAsFixed(1) : 'New',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFFB33E)),
                            ),
                            if (gig.reviewCount > 0)
                              Text(
                                ' (${gig.reviewCount})',
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
                                
                                final favRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('favorites').doc(gig.id);
                                
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
                                            'gigId': gig.id,
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
    );
  }
}
"""
with open('lib/widgets/gig_card.dart', 'w') as f:
    f.write(new_content)
