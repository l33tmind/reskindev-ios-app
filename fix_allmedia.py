import re

with open('lib/screens/gig_detail_screen.dart', 'r') as f:
    c = f.read()

# We need to find the definition of allMedia and replace it
# It looks like:
#     List<String> allMedia = [];
#     if (gig.imageUrl.isNotEmpty) {
#       allMedia.add(gig.imageUrl);
#     ...
#     allMedia.addAll(gig.galleryImages);

pattern = re.compile(r'List<String> allMedia = \[\];.*?allMedia\.addAll\(gig\.galleryImages\);', re.DOTALL)

replacement = """List<String> allMedia = [];
    if (gig.youtubeUrl != null && gig.youtubeUrl!.isNotEmpty) {
      allMedia.add(gig.youtubeUrl!);
      if (gig.imageUrl.isNotEmpty && !gig.imageUrl.contains('img.youtube.com')) {
        allMedia.add(gig.imageUrl);
      }
    } else {
      if (gig.imageUrl.isNotEmpty) {
        allMedia.add(gig.imageUrl);
      }
    }
    allMedia.addAll(gig.galleryImages);"""

c = re.sub(pattern, replacement, c)

with open('lib/screens/gig_detail_screen.dart', 'w') as f:
    f.write(c)

