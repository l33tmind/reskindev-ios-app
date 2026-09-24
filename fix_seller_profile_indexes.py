import re

with open('lib/screens/seller_profile_screen.dart', 'r') as f:
    content = f.read()

# Fix _buildActiveGigs
old_gigs = """  Widget _buildActiveGigs(BuildContext context, String uid) {
    // If admin or md-robius-sany, fetch all general gigs.
    // Otherwise fetch specifically for this authorId.
    final bool isAdmin = uid == 'admin' || uid == 'md-robius-sany';
    
    Query query = FirebaseFirestore.instance.collection('services');
    
    if (isAdmin) {
      // Just filter out pending
      query = query.where('status', isNotEqualTo: 'pending');
    } else {
      query = query.where('authorId', isEqualTo: uid).where('status', isNotEqualTo: 'pending');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator.adaptive());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No active gigs found.'));

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
            mainAxisExtent: 220,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final gig = GigModel.fromFirestore(snapshot.data!.docs[index]);
            return GestureDetector(
              onTap: () => context.push('/gig/${gig.id}', extra: gig),
              child: GigCard(gig: gig, onTap: () => context.push('/gig/${gig.id}', extra: gig)),
            );
          },
        );
      },
    );
  }"""

new_gigs = """  Widget _buildActiveGigs(BuildContext context, String uid) {
    final bool isAdmin = uid == 'admin' || uid == 'md-robius-sany';
    
    Query query = FirebaseFirestore.instance.collection('services');
    if (!isAdmin) {
      query = query.where('authorId', isEqualTo: uid);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error loading gigs: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator.adaptive());
        
        if (!snapshot.hasData) return const Center(child: Text('No active gigs found.'));
        
        // Client-side filtering to avoid composite index requirements
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] != 'pending';
        }).toList();

        if (docs.isEmpty) return const Center(child: Text('No active gigs found.'));

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
            mainAxisExtent: 220,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final gig = GigModel.fromFirestore(docs[index]);
            return GestureDetector(
              onTap: () => context.push('/gig/${gig.id}', extra: gig),
              child: GigCard(gig: gig, onTap: () => context.push('/gig/${gig.id}', extra: gig)),
            );
          },
        );
      },
    );
  }"""

content = content.replace(old_gigs, new_gigs)

# Fix _buildPortfolio
old_portfolio = """  Widget _buildPortfolio(BuildContext context, String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').where('authorId', isEqualTo: uid).where('status', isEqualTo: 'completed').orderBy('completedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator.adaptive());
        
        final docs = snapshot.data?.docs ?? [];
        final portfolioDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['publicReview'] != null && data['publicReview'].toString().isNotEmpty;
        }).toList();"""

new_portfolio = """  Widget _buildPortfolio(BuildContext context, String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').where('authorId', isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error loading portfolio: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator.adaptive());
        
        final docs = snapshot.data?.docs ?? [];
        // Client-side filtering and sorting to avoid complex composite index requirements
        var portfolioDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final isCompleted = data['status'] == 'completed';
          final hasReview = data['publicReview'] != null && data['publicReview'].toString().isNotEmpty;
          return isCompleted && hasReview;
        }).toList();
        
        portfolioDocs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final timeA = dataA['completedAt'] as Timestamp?;
          final timeB = dataB['completedAt'] as Timestamp?;
          if (timeA == null && timeB == null) return 0;
          if (timeA == null) return 1;
          if (timeB == null) return -1;
          return timeB.compareTo(timeA); // descending
        });"""

content = content.replace(old_portfolio, new_portfolio)

with open('lib/screens/seller_profile_screen.dart', 'w') as f:
    f.write(content)

print("Updated seller profile screen to avoid Firebase Composite Indexes.")
