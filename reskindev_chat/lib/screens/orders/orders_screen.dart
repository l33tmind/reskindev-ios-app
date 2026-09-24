import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not logged in'));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Pending'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList(user.uid, 'active'),
          _buildOrderList(user.uid, 'pending'),
          _buildOrderList(user.uid, 'completed'),
        ],
      ),
    );
  }

  Future<String> _getUserRole(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) return doc.data()?['role'] ?? 'buyer';
    } catch (e) {
      debugPrint('Error: $e');
    }
    return 'buyer';
  }

  Widget _buildOrderList(String uid, String status) {
    return FutureBuilder<String>(
      future: _getUserRole(uid),
      builder: (context, roleSnapshot) {
        if (roleSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final role = roleSnapshot.data ?? 'buyer';
        Query orderQuery = FirebaseFirestore.instance.collection('orders');
        
        if (role != 'admin' && role != 'developer') {
          if (role == 'seller' || role == 'freelancer') {
            orderQuery = orderQuery.where('freelancerId', isEqualTo: uid);
          } else {
            orderQuery = orderQuery.where('userId', isEqualTo: uid);
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: orderQuery.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(child: Text('No $status orders found.'));
            }

            // Filter and sort in memory to avoid needing a Firebase Composite Index
            var docs = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['status'] == status;
            }).toList();

            docs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['createdAt'] as Timestamp?;
              final bTime = bData['createdAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });

            if (docs.isEmpty) {
              return Center(child: Text('No $status orders found.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final clientName = data['userName'] ?? 'Client';
                final price = (data['price'] ?? 0).toDouble();
                final title = data['gigTitle'] ?? data['requirements'] ?? 'Custom Order';
                final timestamp = data['createdAt'] as Timestamp?;
                final dateStr = timestamp != null ? DateFormat('MMM d, yyyy').format(timestamp.toDate()) : '';

                return _buildOrderCard(clientName, price, title, status, dateStr);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildOrderCard(String clientName, double price, String title, String status, String dateStr) {
    Color statusColor;
    if (status == 'active') statusColor = Colors.blue;
    else if (status == 'completed') statusColor = Colors.green;
    else statusColor = Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Text(clientName[0].toUpperCase(), style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Text('\$${price.toStringAsFixed(2)}', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(dateStr, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              )
            ],
          )
        ],
      ),
    );
  }
}
