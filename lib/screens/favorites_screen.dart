import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../models/gig_model.dart';
import '../widgets/gig_card.dart';
import '../theme.dart';
import 'package:go_router/go_router.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        title: Text('Wishlist', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
        backgroundColor: context.themeSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: context.themeTextDark),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(auth.user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator.adaptive());
          
          final data = snapshot.hasData && snapshot.data!.exists ? snapshot.data!.data() as Map<String, dynamic> : {};
          final savedGigs = List<String>.from(data['savedGigs'] ?? []);
          
          if (savedGigs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border_rounded, size: 64, color: context.themeTextLight.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('Your Wishlist is Empty', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                  const SizedBox(height: 8),
                  Text('Save your favorite gigs here to buy them later.', style: GoogleFonts.inter(color: context.themeTextLight)),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
              mainAxisExtent: 220,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: savedGigs.length,
            itemBuilder: (context, index) {
              final gigId = savedGigs[index];
              
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('services').doc(gigId).get(),
                builder: (context, gigSnap) {
                  if (gigSnap.connectionState == ConnectionState.waiting) {
                    return Container(
                      decoration: BoxDecoration(color: context.themeSurface, borderRadius: BorderRadius.circular(16)),
                      child: const Center(child: CircularProgressIndicator.adaptive()),
                    );
                  }
                  
                  if (!gigSnap.hasData || !gigSnap.data!.exists) {
                    return Container(
                      decoration: BoxDecoration(color: context.themeSurface, borderRadius: BorderRadius.circular(16)),
                      child: const Center(child: Text('Gig Unavailable')),
                    );
                  }
                  
                  final gig = GigModel.fromFirestore(gigSnap.data!);
                  return GestureDetector(
                    onTap: () => context.push('/gig/\${gig.id}', extra: gig),
                    child: GigCard(gig: gig, onTap: () => context.push('/gig/${gig.id}', extra: gig)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
