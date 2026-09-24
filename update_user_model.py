with open('lib/models/user_model.dart', 'r') as f:
    content = f.read()

fields = """  final String photoUrl;
  final bool isBlocked;
  final DateTime createdAt;
  final String bio;
  final String country;
  final String bannerUrl;
  final List<String> skills;
  final List<String> languages;"""
content = content.replace("  final String photoUrl;\n  final bool isBlocked;\n  final DateTime createdAt;", fields)

constructor = """    required this.photoUrl,
    this.isBlocked = false,
    DateTime? createdAt,
    this.bio = '',
    this.country = '',
    this.bannerUrl = '',
    this.skills = const [],
    this.languages = const [],"""
content = content.replace("    required this.photoUrl,\n    this.isBlocked = false,\n    DateTime? createdAt,", constructor)

from_firestore = """      photoUrl: d['photoUrl'] ?? '',
      isBlocked: d['isBlocked'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      bio: d['bio'] ?? '',
      country: d['country'] ?? '',
      bannerUrl: d['bannerUrl'] ?? '',
      skills: List<String>.from(d['skills'] ?? []),
      languages: List<String>.from(d['languages'] ?? []),"""
content = content.replace("      photoUrl: d['photoUrl'] ?? '',\n      isBlocked: d['isBlocked'] ?? false,\n      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),", from_firestore)

to_map = """    'email': email,
    'photoUrl': photoUrl,
    'isBlocked': isBlocked,
    'bio': bio,
    'country': country,
    'bannerUrl': bannerUrl,
    'skills': skills,
    'languages': languages,"""
content = content.replace("    'email': email,\n    'photoUrl': photoUrl,\n    'isBlocked': isBlocked,", to_map)

with open('lib/models/user_model.dart', 'w') as f:
    f.write(content)
print("Updated user_model.dart")
