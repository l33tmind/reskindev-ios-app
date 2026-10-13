import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/pro_service.dart';

/// Small amber "PRO" pill with a bolt, shown next to a Reskindev Pro member's name.
/// (The blue tick for identity verification is [VerifiedTick].)
class ProBadge extends StatelessWidget {
  final double fontSize;
  const ProBadge({super.key, this.fontSize = 10});

  static const Color amber = Color(0xFFF59E0B);
  static const Color amberDark = Color(0xFFD97706);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.5, vertical: fontSize * 0.15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFBBF24), amber]),
        borderRadius: BorderRadius.circular(fontSize),
        boxShadow: [BoxShadow(color: amber.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: fontSize * 1.25, color: Colors.white),
          Text(
            'PRO',
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.4,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small blue tick for an identity-verified person (users/{uid}.verified == true).
class VerifiedTick extends StatelessWidget {
  final double size;
  const VerifiedTick({super.key, this.size = 15});

  static const Color blue = Color(0xFF1D9BF0);

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Identity verified',
        child: Icon(Icons.verified_rounded, size: size, color: blue),
      );
}

/// [ProBadge] for someone known only by uid: streams users/{uid} and shows the blue tick (when verified)
/// and the PRO badge (while they're Pro). [leading] is the gap placed before the first badge (only when one shows).
class LiveProBadge extends StatelessWidget {
  final String uid;
  final double fontSize;
  final double leading;
  /// Also show the blue tick for verified people.
  final bool showVerified;
  const LiveProBadge({super.key, required this.uid, this.fontSize = 10, this.leading = 6, this.showVerified = true});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final verified = showVerified && data?['verified'] == true;
        final pro = isPro(data);
        if (!verified && !pro) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(left: leading),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (verified) VerifiedTick(size: fontSize * 1.55),
              if (verified && pro) SizedBox(width: fontSize * 0.4),
              if (pro) ProBadge(fontSize: fontSize),
            ],
          ),
        );
      },
    );
  }
}
