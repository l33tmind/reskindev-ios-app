import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';

class AdminReportsView extends StatelessWidget {
  const AdminReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        title: Text('User Reports', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: context.themeSurface,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reports').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator.adaptive());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No reports found.'));
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final reportId = docs[index].id;
              final type = data['type'] ?? 'unknown';
              final gigId = data['gigId'] ?? '';
              final reason = data['reason'] ?? 'No reason provided';
              final reportedBy = data['reportedBy'] ?? 'Unknown';
              final createdAt = data['createdAt'] as Timestamp?;
              
              return Card(
                color: context.themeSurface,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: context.themeBorder)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Report Type: ${type.toString().toUpperCase()}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.red)),
                          if (createdAt != null)
                            Text('${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}', style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Reason: $reason', style: GoogleFonts.inter(color: context.themeTextDark)),
                      const SizedBox(height: 8),
                      Text('Reported By UID: $reportedBy', style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (gigId.isNotEmpty)
                            OutlinedButton(
                              onPressed: () => context.push('/gig/$gigId'),
                              child: const Text('View Gig'),
                            ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('reports').doc(reportId).delete();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report dismissed')));
                              }
                            },
                            child: const Text('Dismiss Report'),
                          ),
                          const Spacer(),
                          if (gigId.isNotEmpty)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () async {
                                await FirebaseFirestore.instance.collection('services').doc(gigId).update({'isActive': false, 'status': 'deleted'});
                                await FirebaseFirestore.instance.collection('reports').doc(reportId).delete();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gig Deleted & Report Dismissed')));
                                }
                              },
                              child: const Text('Delete Gig'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
