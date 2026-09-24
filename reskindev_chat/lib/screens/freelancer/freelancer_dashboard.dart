import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chat/chat_list_screen.dart';
import '../orders/orders_screen.dart';

class FreelancerDashboard extends StatefulWidget {
  const FreelancerDashboard({super.key});

  @override
  State<FreelancerDashboard> createState() => _FreelancerDashboardState();
}

class _FreelancerDashboardState extends State<FreelancerDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final List<Widget> screens = [
      _DashboardHome(user: user),
      const ChatListScreen(),
      const OrdersScreen(),
      const Center(child: Text('Profile Screen (Coming Soon)')),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: Theme.of(context).primaryColor,
            unselectedItemColor: Colors.grey[400],
            showUnselectedLabels: true,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_rounded), activeIcon: Icon(Icons.chat_bubble_rounded), label: 'Inbox'),
              BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHome extends StatelessWidget {
  final User user;
  const _DashboardHome({required this.user});

  Future<String> _getUserRole() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data()?['role'] ?? 'buyer';
      }
    } catch (e) {
      debugPrint('Error fetching role: $e');
    }
    return 'buyer'; // default fallback
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getUserRole(),
      builder: (context, roleSnapshot) {
        if (roleSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final role = roleSnapshot.data ?? 'buyer';
        
        Query orderQuery = FirebaseFirestore.instance.collection('orders');
        
        // Apply role-based filtering
        if (role != 'admin' && role != 'developer') {
          if (role == 'seller' || role == 'freelancer') {
            orderQuery = orderQuery.where('freelancerId', isEqualTo: user.uid);
          } else {
            // Default to buyer
            orderQuery = orderQuery.where('userId', isEqualTo: user.uid);
          }
        } // If admin, keep the query unrestricted

        return StreamBuilder<QuerySnapshot>(
          stream: orderQuery.snapshots(),
          builder: (context, snapshot) {
            double totalEarned = 0;
            double pendingClearance = 0;
            int activeCount = 0;
            int pendingCount = 0;
            int completedCount = 0;
            int cancelledCount = 0;

            if (snapshot.hasData) {
              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] as String? ?? 'pending';
                final price = (data['price'] ?? 0).toDouble();

                if (status == 'completed') {
                  completedCount++;
                  totalEarned += price;
                } else if (status == 'active') {
                  activeCount++;
                  pendingClearance += price;
                } else if (status == 'pending') {
                  pendingCount++;
                  pendingClearance += price;
                } else if (status == 'cancelled') {
                  cancelledCount++;
                }
              }
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                              backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                              child: user.photoURL == null ? Text(user.displayName?[0].toUpperCase() ?? 'U', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)) : null,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Welcome back,', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                Text(user.displayName ?? 'User', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                          child: IconButton(icon: const Icon(Icons.notifications_none_rounded), onPressed: () {}),
                        )
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Earnings Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C6A2), Color(0xFF6C5CE7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF00C6A2).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            top: -20,
                            child: Icon(Icons.account_balance_wallet, size: 100, color: Colors.white.withOpacity(0.1)),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                                child: Text(
                                  role == 'admin' || role == 'developer' ? 'Total Platform Revenue' : (role == 'buyer' || role == 'user' ? 'Total Spent' : 'Available Balance'), 
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text('\$${totalEarned.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: -1)),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(role == 'buyer' || role == 'user' ? 'Completed Spending' : 'Total Earned', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text('\$${totalEarned.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2)),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(role == 'buyer' || role == 'user' ? 'Pending Escrow' : 'Pending Clearance', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text('\$${pendingClearance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Order Stats Grid
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Order Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton(onPressed: () {}, child: Text('View All', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.2,
                      children: [
                        _buildModernStatCard('Active', activeCount.toString(), Icons.autorenew_rounded, Colors.blue, context),
                        _buildModernStatCard('Pending', pendingCount.toString(), Icons.hourglass_empty_rounded, Colors.orange, context),
                        _buildModernStatCard('Completed', completedCount.toString(), Icons.check_circle_outline_rounded, Colors.green, context),
                        _buildModernStatCard('Cancelled', cancelledCount.toString(), Icons.cancel_outlined, Colors.red, context),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildModernStatCard(String title, String count, IconData icon, Color iconColor, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: iconColor.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                Text(count, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
