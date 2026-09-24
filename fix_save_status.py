import re

with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    content = f.read()

old_save = """      final payload = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _category,
        'imageUrl': imageUrl,
        'galleryImages': gallery,
        'packages': packages.map((p) => p.toMap()).toList(),
        'masterFeatures': _masterFeatures,
        'status': _status,
        'searchTokens': _generateSearchTokens(_titleCtrl.text),
        'youtubeUrl': _youtubeCtrl.text.trim(),
        'youtubeUrls': _youtubeCtrl.text.trim().isNotEmpty ? [_youtubeCtrl.text.trim()] : [],
        'videoConsent': _ugcAccepted,"""

new_save = """      final user = FirebaseAuth.instance.currentUser;
      final isAdmin = user?.uid == 'md-robius-sany' || user?.email?.toLowerCase() == 'mdrobiussany1225@gmail.com';
      if (!isAdmin) {
        _status = 'pending';
      }
      
      final payload = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _category,
        'imageUrl': imageUrl,
        'galleryImages': gallery,
        'packages': packages.map((p) => p.toMap()).toList(),
        'masterFeatures': _masterFeatures,
        'status': _status,
        'searchTokens': _generateSearchTokens(_titleCtrl.text),
        'youtubeUrl': _youtubeCtrl.text.trim(),
        'youtubeUrls': _youtubeCtrl.text.trim().isNotEmpty ? [_youtubeCtrl.text.trim()] : [],
        'videoConsent': _ugcAccepted,"""

if old_save in content:
    content = content.replace(old_save, new_save)
    with open('lib/screens/gig_editor_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed _save status")
else:
    print("Could not find old_save payload!")

# I also need to hide the dropdowns completely for non-admins to prevent UI errors
# Actually, if the dropdown value is 'pending' and the user is NOT an admin, it'll still crash IF 'pending' is NOT in the items list. But 'pending' IS in the items list.
# But hiding it is cleaner.

mobile_dropdown = """if (FirebaseAuth.instance.currentUser?.email?.toLowerCase() == 'mdrobiussany1225@gmail.com')"""
new_mobile_dropdown = """if (FirebaseAuth.instance.currentUser?.email?.toLowerCase() == 'mdrobiussany1225@gmail.com' || FirebaseAuth.instance.currentUser?.uid == 'md-robius-sany')"""

content = content.replace(mobile_dropdown, new_mobile_dropdown)
with open('lib/screens/gig_editor_screen.dart', 'w') as f:
    f.write(content)

