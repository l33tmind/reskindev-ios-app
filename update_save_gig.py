import re

with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    content = f.read()

# Replace the media saving logic inside _saveGig
old_save_logic = """      final mediaUrl = _mediaCtrl.text.trim();
      
      // Smart media split: YouTube URL → youtubeUrl field + thumbnail as imageUrl
      // If it's a direct image URL, youtubeUrl is empty and imageUrl has it.
      String imageUrl = '';
      String youtubeUrl = '';
      
      if (mediaUrl.isNotEmpty) {
        final isYT = _isYouTubeUrl(mediaUrl);
        if (isYT) {
          youtubeUrl = mediaUrl;
          final videoId = _extractVideoId(mediaUrl);
          imageUrl = videoId != null
              ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg'
              : '';
        } else {
          imageUrl = mediaUrl;
        }
      }"""

new_save_logic = """      String youtubeUrl = _youtubeCtrl.text.trim();
      String imageUrl = _uploadedImageUrl;"""

content = content.replace(old_save_logic, new_save_logic)

with open('lib/screens/gig_editor_screen.dart', 'w') as f:
    f.write(content)
print("Updated _saveGig logic")
