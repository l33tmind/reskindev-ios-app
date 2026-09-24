import re

with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    content = f.read()

# Replace _mediaCtrl declaration
content = content.replace("late TextEditingController _mediaCtrl;", "late TextEditingController _youtubeCtrl;\n  String _uploadedImageUrl = '';\n  bool _isUploadingImage = false;")

# Replace initState initialization
old_init = """    final existingMedia = (g?.youtubeUrl != null && g!.youtubeUrl!.isNotEmpty)
        ? g.youtubeUrl!
        : (g?.imageUrl ?? '');
    _mediaCtrl = TextEditingController(text: existingMedia);"""

new_init = """    _youtubeCtrl = TextEditingController(text: g?.youtubeUrl ?? '');
    _uploadedImageUrl = g?.imageUrl ?? '';"""
content = content.replace(old_init, new_init)

# Replace disposing
content = content.replace("_mediaCtrl.dispose();", "_youtubeCtrl.dispose();")

with open('lib/screens/gig_editor_screen.dart', 'w') as f:
    f.write(content)
print("Splitted media variables")
