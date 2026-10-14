import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A person's picture, the same everywhere (chat, inbox, orders).
///
/// Shows their profile photo; without one, their initials on a color picked from their user id,
/// so two people never look the same (two guests used to be two identical teal "G" circles).
/// With [uid] it reads the live photo from users/{uid} ([photoUrl] is the fallback), so a new photo shows up everywhere.
class UserAvatar extends StatelessWidget {
  final String? uid;
  final String name;
  final String? photoUrl;
  final double radius;
  final bool showOnline;

  const UserAvatar({
    super.key,
    this.uid,
    required this.name,
    this.photoUrl,
    this.radius = 18,
    this.showOnline = false,
  });

  static const _palette = [
    Color(0xFF0EA5E9), Color(0xFF8B5CF6), Color(0xFFF97316), Color(0xFF10B981),
    Color(0xFFEC4899), Color(0xFF6366F1), Color(0xFFEAB308), Color(0xFF14B8A6),
  ];

  static Color colorFor(String key) {
    var h = 0;
    for (final c in key.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

  /// "Guest 4828" → "G4", "Robius Sany" → "RS", "robiussani" → "R"
  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final given = photoUrl ?? '';
    if (uid == null || uid!.isEmpty) return _circle(context, given, name);
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        var url = (data?['photoUrl'] ?? data?['profilePicture'] ?? '').toString();
        if (url.isEmpty) url = given;
        final liveName = (data?['name'] ?? data?['displayName'] ?? '').toString();
        final online = data?['isOnline'] == true;
        return _circle(context, url, liveName.isNotEmpty ? liveName : name, online: online);
      },
    );
  }

  Widget _circle(BuildContext context, String url, String displayName, {bool online = false}) {
    final color = colorFor(uid ?? displayName);
    final size = radius * 2;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        initialsOf(displayName),
        style: GoogleFonts.inter(fontSize: radius * 0.75, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );

    final Widget picture = SizedBox(
      width: size,
      height: size,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: url.isEmpty
              ? fallback
              : CachedNetworkImage(
                  imageUrl: url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  memCacheWidth: (size * 3).round(),
                  imageBuilder: (context, imageProvider) => Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  placeholder: (_, __) => fallback,
                  errorWidget: (_, __, ___) => fallback,
                ),
        ),
      ),
    );

    final Widget avatar = (!showOnline || !online)
        ? picture
        : SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                picture,
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: radius * 0.6,
                    height: radius * 0.6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          );

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: avatar,
        ),
      ),
    );
  }
}

/// A person's current name from users/{uid} (the name saved in a chat can be old, or "Unknown").
class LiveUserName extends StatelessWidget {
  final String uid;
  final String fallback;
  final TextStyle? style;
  const LiveUserName({super.key, required this.uid, required this.fallback, this.style});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return Text(fallback, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        var name = (data?['name'] ?? data?['displayName'] ?? data?['username'] ?? '').toString().trim();
        if (name.isEmpty) name = fallback == 'Unknown' ? 'User' : fallback;
        return Text(name, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
      },
    );
  }
}
