import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../models/user_model.dart';

class AdminUsersView extends StatelessWidget {
  const AdminUsersView({super.key});

  Future<void> _toggleBlockStatus(BuildContext context, UserModel user) async {
    final newStatus = !user.isBlocked;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'isBlocked': newStatus,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User ${user.name} is now ${newStatus ? 'blocked' : 'unblocked'}.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }
        
        final users = (snap.data?.docs ?? [])
            .map((d) => UserModel.fromFirestore(d))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User Management',
                  style: GoogleFonts.outfit(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w800, color: context.themeTextDark)),
              const SizedBox(height: 8),
              Text('Manage registered users and their access.',
                  style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: context.themeSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.themeBorder),
                  boxShadow: [
                    BoxShadow(color: context.isDarkMode ? Colors.transparent : Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: context.themeBorder.withValues(alpha: 0.5)),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: isMobile ? _buildMobileUserItem(context, user) : _buildDesktopUserItem(context, user),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopUserItem(BuildContext context, UserModel user) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
          backgroundColor: AppTheme.primary,
          child: user.photoUrl.isEmpty ? Icon(Icons.person, color: Colors.white) : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: context.themeTextDark), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(user.email, style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        _buildStatusChip(user.isBlocked),
        const SizedBox(width: 24),
        SizedBox(
          width: 120,
          child: ElevatedButton(
            onPressed: () => _toggleBlockStatus(context, user),
            style: ElevatedButton.styleFrom(
              backgroundColor: user.isBlocked ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(user.isBlocked ? 'Unblock' : 'Block'),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileUserItem(BuildContext context, UserModel user) {
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
              backgroundColor: AppTheme.primary,
              child: user.photoUrl.isEmpty ? Icon(Icons.person, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: context.themeTextDark)),
                  Text(user.email, style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            _buildStatusChip(user.isBlocked),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed: () => _toggleBlockStatus(context, user),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: user.isBlocked ? Colors.green : Colors.red),
              foregroundColor: user.isBlocked ? Colors.green : Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(user.isBlocked ? 'Unblock User' : 'Block User', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(bool isBlocked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isBlocked ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isBlocked ? 'Blocked' : 'Active',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isBlocked ? Colors.red : Colors.green,
        ),
      ),
    );
  }
}
