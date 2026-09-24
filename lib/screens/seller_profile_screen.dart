import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import '../models/gig_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../widgets/gig_card.dart';

class SellerProfileScreen extends StatefulWidget {
  final String sellerId;
  final String? fallbackName;
  final String? fallbackImage;
  const SellerProfileScreen({super.key, required this.sellerId, this.fallbackName, this.fallbackImage});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  int _totalOrders = 0;
  double _averageRating = 0.0;
  int _reviewCount = 0;
  bool _statsLoaded = false;
  
  UserModel? _loadedUser;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _fetchSellerStats();
    _fetchUserData();
  }
  
  Future<void> _fetchUserData() async {
    try {
      // 1. Try fetching by Document ID
      final docSnap = await FirebaseFirestore.instance.collection('users').doc(widget.sellerId).get();
      if (docSnap.exists) {
        setState(() {
          _loadedUser = UserModel.fromFirestore(docSnap);
          _isLoadingUser = false;
        });
        return;
      }
      
      // 2. Fallback: query by username
      final querySnap = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: widget.sellerId).limit(1).get();
      if (querySnap.docs.isNotEmpty) {
        setState(() {
          _loadedUser = UserModel.fromFirestore(querySnap.docs.first);
          _isLoadingUser = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Error fetching user: $e');
    }
    
    // 3. Fallback: Use gig data
    setState(() {
      _loadedUser = UserModel(
        uid: widget.sellerId,
        email: '',
        name: widget.fallbackName ?? 'Verified Seller',
        displayName: widget.fallbackName ?? 'Verified Seller',
        photoUrl: widget.fallbackImage ?? '',
        createdAt: DateTime.now(),
      );
      _isLoadingUser = false;
    });
  }

  Future<void> _fetchSellerStats() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('authorId', isEqualTo: widget.sellerId)
          .get();
          
      final completedDocs = snap.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'completed';
      }).toList();

      int orders = completedDocs.length;
      double totalRating = 0.0;
      int reviews = 0;

      for (var doc in completedDocs) {
        final data = doc.data();
        if (data['overallRating'] != null) {
          totalRating += (data['overallRating'] as num).toDouble();
          reviews++;
        }
      }

      if (mounted) {
        setState(() {
          _totalOrders = orders;
          _reviewCount = reviews;
          _averageRating = reviews > 0 ? (totalRating / reviews) : 0.0;
          _statsLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statsLoaded = true);
      }
    }
  }

  void _contactSeller(UserModel user) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      context.push("/login");
    } else if (currentUser.uid != user.uid) {
      context.push('/chat/new', extra: {
        'targetUserId': user.uid,
        'targetUserName': user.displayName.isNotEmpty ? user.displayName : 'Verified Seller',
        'targetUserAvatar': user.photoUrl,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot message yourself.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        title: Text('Seller Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
        backgroundColor: context.themeSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: context.themeTextDark),
      ),
      body: _isLoadingUser 
        ? const Center(child: CircularProgressIndicator.adaptive())
        : (_loadedUser == null 
            ? const Center(child: Text('Seller not found')) 
            : _buildProfileContent(context, _loadedUser!)),
    );
  }

  Widget _buildProfileContent(BuildContext context, UserModel user) {
    return DefaultTabController(
      length: 2,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: _buildHeader(context, user),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: context.themeTextLight,
                  indicatorColor: AppTheme.primary,
                  indicatorWeight: 3,
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'Services'),
                    Tab(text: 'Portfolio & Reviews'),
                  ],
                ),
                context.themeSurface,
              ),
            ),
          ];
        },
        body: TabBarView(
          children: [
            _buildActiveGigs(context, user.uid),
            _buildPortfolio(context, user.uid),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserModel user) {
    return Container(
      color: context.themeSurface,
      child: Column(
        children: [
          // Banner & Avatar
          SizedBox(
            height: 200,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Banner
                Positioned(
                  top: 0, left: 0, right: 0, bottom: 50,
                  child: Container(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    width: double.infinity,
                    child: user.bannerUrl.isNotEmpty
                        ? Image.network(user.bannerUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey.shade200))
                        : Icon(Icons.storefront_outlined, size: 64, color: AppTheme.primary.withValues(alpha: 0.2)),
                  ),
                ),
                // Avatar
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: context.themeSurface, shape: BoxShape.circle),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                      child: user.photoUrl.isEmpty
                          ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'S',
                              style: const TextStyle(fontSize: 36, color: AppTheme.primary, fontWeight: FontWeight.bold))
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Name & Bio
          Text(user.displayName.isNotEmpty ? user.displayName : 'Verified Seller',
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: context.themeTextDark)),
          if (user.bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(user.bio, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(Icons.star_rounded, _averageRating > 0 ? _averageRating.toStringAsFixed(1) : 'New', 'Rating', color: Colors.orange),
              _buildStatItem(Icons.thumb_up_alt_outlined, '$_reviewCount', 'Reviews', color: Colors.blue),
              _buildStatItem(Icons.shopping_bag_outlined, '$_totalOrders', 'Completed', color: Colors.green),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Contact Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _contactSeller(user),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('Contact Me'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ),
          
          if (user.skills.isNotEmpty) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Skills', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: user.skills.map((skill) => Chip(
                      label: Text(skill, style: GoogleFonts.inter(fontSize: 12)),
                      backgroundColor: context.themeBackground,
                      side: BorderSide(color: context.themeBorder),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, {Color? color}) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color ?? context.themeTextDark),
            const SizedBox(width: 4),
            Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: context.themeTextDark)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
      ],
    );
  }

  Widget _buildActiveGigs(BuildContext context, String uid) {
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
  }

  Widget _buildPortfolio(BuildContext context, String uid) {
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
        });

        if (portfolioDocs.isEmpty) return const Center(child: Text('No reviews yet.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: portfolioDocs.length,
          itemBuilder: (context, index) {
            final order = OrderModel.fromFirestore(portfolioDocs[index]);
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              color: context.themeSurface,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: context.themeBorder)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.gigTitle, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.orange, size: 20),
                        const SizedBox(width: 4),
                        Text('${order.overallRating?.toStringAsFixed(1) ?? "5.0"}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: context.themeTextDark)),
                        const SizedBox(width: 12),
                        if (order.completedAt != null)
                          Text('${order.completedAt!.day}/${order.completedAt!.month}/${order.completedAt!.year}', style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: context.themeBackground, borderRadius: BorderRadius.circular(8)),
                      child: Text('"${order.publicReview}"', style: GoogleFonts.inter(fontStyle: FontStyle.italic, color: context.themeTextDark)),
                    ),

                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color backgroundColor;

  _SliverAppBarDelegate(this._tabBar, this.backgroundColor);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
