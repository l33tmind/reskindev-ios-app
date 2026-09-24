import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String displayName;
  final String email;
  final String photoUrl;
  final bool isBlocked;
  final DateTime createdAt;
  final String bio;
  final String country;
  final String bannerUrl;
  final List<String> skills;
  final List<String> languages;

  UserModel({
    required this.uid,
    required this.name,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    this.isBlocked = false,
    DateTime? createdAt,
    this.bio = '',
    this.country = '',
    this.bannerUrl = '',
    this.skills = const [],
    this.languages = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>?;
    if (d == null) {
      return UserModel(uid: doc.id, name: 'Unknown', displayName: '', email: '', photoUrl: '');
    }
    return UserModel(
      uid: d['uid'] ?? doc.id,
      name: d['name'] ?? '',
      displayName: d['displayName'] ?? '',
      email: d['email'] ?? '',
      photoUrl: d['photoUrl'] ?? '',
      isBlocked: d['isBlocked'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      bio: d['bio'] ?? '',
      country: d['country'] ?? '',
      bannerUrl: d['bannerUrl'] ?? '',
      skills: List<String>.from(d['skills'] ?? []),
      languages: List<String>.from(d['languages'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'name': name,
    'displayName': displayName,
    'email': email,
    'photoUrl': photoUrl,
    'isBlocked': isBlocked,
    'bio': bio,
    'country': country,
    'bannerUrl': bannerUrl,
    'skills': skills,
    'languages': languages,
  };
}
