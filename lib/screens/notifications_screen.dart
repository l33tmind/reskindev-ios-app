import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../providers/auth_provider.dart';
import '../theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    
    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.themeTextDark)),
        backgroundColor: context.themeSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: context.themeTextDark),
        centerTitle: true,
      ),
      body: auth.user == null
          ? Center(child: Text('Please login to view notifications', style: GoogleFonts.inter(color: context.themeTextLight)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(auth.user!.uid)
                  .collection('notifications')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator.adaptive());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_rounded, size: 64, color: context.themeTextLight.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text('No notifications yet', style: GoogleFonts.inter(fontSize: 16, color: context.themeTextLight)),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final title = data['title'] ?? 'Notification';
                    final body = data['body'] ?? '';
                    final isRead = data['isRead'] ?? false;
                    final timestamp = data['createdAt'] as Timestamp?;
                    
                    return Card(
                      elevation: 0,
                      margin: EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isRead ? context.themeBorder : AppTheme.primary.withOpacity(0.3), width: isRead ? 1 : 1.5),
                      ),
                      color: isRead ? context.themeSurface : AppTheme.primary.withOpacity(0.05),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isRead ? context.themeBackground : AppTheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications_active_rounded,
                            color: isRead ? context.themeTextLight : AppTheme.primary,
                          ),
                        ),
                        title: Text(title, style: GoogleFonts.outfit(fontWeight: isRead ? FontWeight.w600 : FontWeight.w700, fontSize: 16, color: context.themeTextDark)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(body, style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
                            if (timestamp != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                timeago.format(timestamp.toDate()),
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ]
                          ],
                        ),
                        onTap: () {
                          if (!isRead) {
                            docs[index].reference.update({'isRead': true});
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
