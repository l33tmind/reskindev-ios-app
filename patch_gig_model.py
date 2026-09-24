import re

with open('lib/models/gig_model.dart', 'r') as f:
    c = f.read()

# Add isVacation property
old_prop = """  final String authorName;
  final List<String> keywords; // Search keywords/tags"""

new_prop = """  final String authorName;
  final List<String> keywords; // Search keywords/tags
  final bool isVacation;"""

c = c.replace(old_prop, new_prop)

# Add to constructor
old_ctor = """    this.authorId = '',
    this.authorName = '',
    this.keywords = const [],"""

new_ctor = """    this.authorId = '',
    this.authorName = '',
    this.keywords = const [],
    this.isVacation = false,"""

c = c.replace(old_ctor, new_ctor)

# Add to fromFirestore
old_from = """      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',"""

new_from = """      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      isVacation: data['isVacation'] ?? false,"""

c = c.replace(old_from, new_from)

# Add to toMap
old_to = """      'authorName': authorName,
      'reviewCount': reviewCount,"""

new_to = """      'authorName': authorName,
      'isVacation': isVacation,
      'reviewCount': reviewCount,"""

c = c.replace(old_to, new_to)

# Update isVisible
old_vis = """  /// Check if the gig is visible to public (active or published)
  bool get isVisible => status == 'active' || status == 'published';"""

new_vis = """  /// Check if the gig is visible to public (active or published)
  bool get isVisible => (status == 'active' || status == 'published') && !isVacation;"""

c = c.replace(old_vis, new_vis)

with open('lib/models/gig_model.dart', 'w') as f:
    f.write(c)

