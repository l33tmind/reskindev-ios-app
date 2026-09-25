import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

class UserStatusIndicator extends StatelessWidget {
  final String userId;
  final bool showText;
  
  const UserStatusIndicator({
    super.key, 
    required this.userId,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox();
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final lastSeenRaw = data['lastSeen'];
        final isOnlineOverride = data['isOnline'] as bool? ?? false;
        
        bool isOnline = isOnlineOverride;
        String text = 'Offline';
        
        DateTime? lastSeen;
        if (lastSeenRaw is Timestamp) {
          lastSeen = lastSeenRaw.toDate();
        } else if (lastSeenRaw is int) {
          lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenRaw);
        }
        
        if (lastSeen != null) {
          if (DateTime.now().difference(lastSeen).inMinutes < 3) {
            isOnline = true;
            text = 'Online';
          } else {
            isOnline = false;
            text = 'Active ${timeago.format(lastSeen)}';
          }
        } else {
            isOnline = false;
            text = 'Active ${timeago.format(lastSeen)}';
          }
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? Colors.green : Colors.grey,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: isOnline ? [
                  BoxShadow(color: Colors.green.withValues(alpha: 0.5), blurRadius: 4, spreadRadius: 1)
                ] : null,
              ),
            ),
            if (showText) ...[
              const SizedBox(width: 6),
              Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isOnline ? Colors.green : Colors.grey.shade600,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
