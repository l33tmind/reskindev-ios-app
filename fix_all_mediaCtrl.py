with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    content = f.read()

# Fix 1: _save() validation check
content = content.replace(
    "    if (_mediaCtrl.text.trim().isNotEmpty && !_ugcAccepted) {",
    "    if ((_uploadedImageUrl.isNotEmpty || _youtubeCtrl.text.trim().isNotEmpty) && !_ugcAccepted) {"
)

# Fix 2: the old save logic inside _saveGig (the old _save() method that wasn't renamed yet)
old_save = """      // Smart media split: YouTube URL → youtubeUrl field + thumbnail as imageUrl
      final mediaUrl = _mediaCtrl.text.trim();
      String imageUrl = '';
      String? youtubeUrl;
      if (_isYouTubeUrl(mediaUrl)) {
        youtubeUrl = mediaUrl;
        final videoId = _extractVideoId(mediaUrl);
        // Auto-generate thumbnail URL from YouTube
        imageUrl = videoId != null
            ? 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg'
            : '';"""

new_save = """      String imageUrl = _uploadedImageUrl;
      String? youtubeUrl = _youtubeCtrl.text.trim().isNotEmpty ? _youtubeCtrl.text.trim() : null;
      if (youtubeUrl != null && imageUrl.isEmpty) {
        final videoId = _extractVideoId(youtubeUrl);
        // Auto-generate thumbnail URL from YouTube only if no custom image
        imageUrl = videoId != null
            ? 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg'
            : '';"""

content = content.replace(old_save, new_save)

with open('lib/screens/gig_editor_screen.dart', 'w') as f:
    f.write(content)
print("Fixed _mediaCtrl references in _save()")
