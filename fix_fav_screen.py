import re

with open('lib/screens/favorites_screen.dart', 'r') as f:
    content = f.read()

old_block = """      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(auth.user!.uid).collection('favorites').orderBy('addedAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator.adaptive());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

          final favDocs = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
              mainAxisExtent: 220,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: favDocs.length,
            itemBuilder: (context, index) {
              final gigId = favDocs[index]['gigId'] as String;"""

new_block = """      body: StreamBuilder<DocumentSnapshot>(
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
              final gigId = savedGigs[index];"""

if old_block in content:
    content = content.replace(old_block, new_block)
    with open('lib/screens/favorites_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed FavoritesScreen")
else:
    print("Could not find old block in FavoritesScreen")
