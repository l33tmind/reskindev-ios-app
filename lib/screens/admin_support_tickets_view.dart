import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';

class AdminSupportTicketsView extends StatelessWidget {
  const AdminSupportTicketsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Support Tickets', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: context.themeTextDark)),
          const SizedBox(height: 8),
          Text('Manage disputes and user issues.', style: GoogleFonts.inter(color: context.themeTextLight)),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('support_tickets').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator.adaptive());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No support tickets found.'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'open';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: context.themeSurface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: context.themeBorder)),
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(data['subject'] ?? 'No Subject', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.themeTextDark))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: status == 'open' ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(status.toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: status == 'open' ? Colors.red : Colors.green)),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Order: \${data["gigTitle"]}', style: GoogleFonts.inter(color: context.themeTextLight, fontSize: 13)),
                            const SizedBox(height: 8),
                            Text(data['description'] ?? '', style: GoogleFonts.inter(color: context.themeTextDark)),
                            const SizedBox(height: 16),
                            if (status == 'open')
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () async {
                                    await FirebaseFirestore.instance.collection('support_tickets').doc(doc.id).update({'status': 'resolved'});
                                  },
                                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                                  child: const Text('Mark as Resolved'),
                                ),
                              )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
