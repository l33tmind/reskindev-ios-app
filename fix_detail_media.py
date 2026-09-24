import re

with open('lib/screens/gig_detail_screen.dart', 'r') as f:
    content = f.read()

old_media = """    List<String> allMedia = [];
    if (gig.youtubeUrl != null && gig.youtubeUrl!.isNotEmpty) {
      allMedia.add(gig.youtubeUrl!);
    } else if (gig.imageUrl.isNotEmpty) {
      allMedia.add(gig.imageUrl);
    }
    allMedia.addAll(gig.galleryImages);"""

new_media = """    List<String> allMedia = [];
    if (gig.imageUrl.isNotEmpty) {
      allMedia.add(gig.imageUrl);
    }
    if (gig.youtubeUrl != null && gig.youtubeUrl!.isNotEmpty) {
      allMedia.add(gig.youtubeUrl!);
    }
    allMedia.addAll(gig.galleryImages);"""

content = content.replace(old_media, new_media)

with open('lib/screens/gig_detail_screen.dart', 'w') as f:
    f.write(content)
print("Updated gig_detail_screen.dart media priority")
