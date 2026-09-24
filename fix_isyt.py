import re

with open('lib/screens/gig_detail_screen.dart', 'r') as f:
    c = f.read()

# Replace general youtube.com checks with youtube.com/watch
c = c.replace("mediaUrl.contains('youtube.com') || mediaUrl.contains('youtu.be')", "mediaUrl.contains('youtube.com/watch') || mediaUrl.contains('youtu.be/')")
c = c.replace("currentMedia.contains('youtube.com/') || currentMedia.contains('youtu.be/')", "currentMedia.contains('youtube.com/watch') || currentMedia.contains('youtu.be/')")
c = c.replace("media.contains('youtube.com/') || media.contains('youtu.be/')", "media.contains('youtube.com/watch') || media.contains('youtu.be/')")
c = c.replace("allMedia[_selectedMediaIndex].contains('youtube.com') || allMedia[_selectedMediaIndex].contains('youtu.be')", "allMedia[_selectedMediaIndex].contains('youtube.com/watch') || allMedia[_selectedMediaIndex].contains('youtu.be/')")

with open('lib/screens/gig_detail_screen.dart', 'w') as f:
    f.write(c)

