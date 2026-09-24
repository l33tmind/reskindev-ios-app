import re

with open('lib/widgets/gig_card.dart', 'r') as f:
    content = f.read()

old_func = """  String _getThumbnailUrl(GigModel gig) {
    if (gig.youtubeUrl != null && gig.youtubeUrl!.isNotEmpty) {
      final ytThumb = _getYoutubeThumbnail(gig.youtubeUrl);
      if (ytThumb != null) return ytThumb;
    }
    if (gig.galleryImages.isNotEmpty) return gig.galleryImages.first;
    if (gig.images.isNotEmpty) return gig.images.first;
    if (gig.imageUrl.isNotEmpty) return gig.imageUrl;
    return '';
  }"""

new_func = """  String _getThumbnailUrl(GigModel gig) {
    if (gig.imageUrl.isNotEmpty) return gig.imageUrl;
    if (gig.images.isNotEmpty) return gig.images.first;
    if (gig.galleryImages.isNotEmpty) return gig.galleryImages.first;
    if (gig.youtubeUrl != null && gig.youtubeUrl!.isNotEmpty) {
      final ytThumb = _getYoutubeThumbnail(gig.youtubeUrl);
      if (ytThumb != null) return ytThumb;
    }
    return '';
  }"""

content = content.replace(old_func, new_func)

with open('lib/widgets/gig_card.dart', 'w') as f:
    f.write(content)
print("Updated gig_card thumbnail priority")
