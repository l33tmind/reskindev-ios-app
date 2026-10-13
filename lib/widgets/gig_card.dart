import 'package:flutter/material.dart';
import 'gig_cover.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/gig_model.dart';
import '../theme.dart';
import '../services/soft_sound.dart';
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  thumbnailUrl.isNotEmpty
                  ? Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => GigCover(gig: gig, showTitle: false),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(color: context.themeSurface);
                      },
                    )
                  : GigCover(gig: gig, showTitle: false),
                ],
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
                        // A long seller name ends with "..." before it reaches the heart
                        const SizedBox(width: 4),
                        _HeartButton(gig: gig),
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
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFFFB33E), size: 14),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  gig.averageRating > 0 ? gig.averageRating.toStringAsFixed(1) : 'New',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFFB33E)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (gig.reviewCount > 0)
                                Flexible(
                                  child: Text(
                                    ' (${gig.reviewCount})',
                                    style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                        ),
                        ),
                        
                        // Right: Price
                        Row(
                          children: [
                            Text(
                              'From ',
                              style: GoogleFonts.inter(fontSize: 10, color: context.themeTextLight, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '\$${startingPrice.toStringAsFixed(0)}',
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

class _HeartButton extends StatefulWidget {
  final GigModel gig;
  const _HeartButton({required this.gig});

  @override
  State<_HeartButton> createState() => _HeartButtonState();
}

class _HeartButtonState extends State<_HeartButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 60),
    ]).animate(_pop);

    Widget heart(bool filled, VoidCallback onTap) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 28,
            height: 24,
            child: Center(
              child: ScaleTransition(
                scale: scale,
                child: Icon(
                  filled ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 20,
                  color: filled ? Colors.redAccent : context.themeTextLight,
                ),
              ),
            ),
          ),
        );

    if (user == null) {
      return heart(false, () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to add to wishlist')));
        context.push('/login');
      });
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    return StreamBuilder<DocumentSnapshot>(
      stream: userRef.snapshots(),
      builder: (context, snapshot) {
        var isFav = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          isFav = List<String>.from(data['savedGigs'] ?? []).contains(widget.gig.id);
        }
        return heart(isFav, () async {
          if (isFav) {
            await userRef.update({'savedGigs': FieldValue.arrayRemove([widget.gig.id])});
          } else {
            _pop.forward(from: 0);
            SoftSound.chime();
            await userRef.update({'savedGigs': FieldValue.arrayUnion([widget.gig.id])});
          }
        });
      },
    );
  }
}
