import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/order_model.dart';
import '../theme.dart';
import 'admin_dashboard_screen.dart'; // To access AdminOrderListItem

class AdminOrdersView extends StatefulWidget {
  const AdminOrdersView({super.key});

  @override
  State<AdminOrdersView> createState() => _AdminOrdersViewState();
}

class _AdminOrdersViewState extends State<AdminOrdersView> {
  String _searchQuery = '';
  String _selectedStatus = 'All';
  late Stream<QuerySnapshot> _ordersStream;
  final TextEditingController _searchController = TextEditingController();
  
  final List<String> _statuses = ['All', 'pending', 'in_progress', 'completed', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _ordersStream = FirebaseFirestore.instance.collection('orders').snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _ordersStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }
        
        var orders = (snap.data?.docs ?? [])
            .map((d) => OrderModel.fromFirestore(d))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Filter by Status
        if (_selectedStatus != 'All') {
          orders = orders.where((o) => o.status.toLowerCase() == _selectedStatus.toLowerCase()).toList();
        }

        // Filter by Search Query
        if (_searchQuery.trim().isNotEmpty) {
          final query = _searchQuery.trim().toLowerCase();
          orders = orders.where((o) {
            final emailMatch = o.clientEmail.toLowerCase().contains(query);
            final nameMatch = o.clientName.toLowerCase().contains(query);
            final gigMatch = o.gigTitle.toLowerCase().contains(query);
            // Can add phone match if phone is added to OrderModel in future
            return emailMatch || nameMatch || gigMatch;
          }).toList();
        }

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width < 600 ? 16 : 40,
              vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('All Orders',
                            style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: context.themeTextDark)),
                        const SizedBox(height: 8),
                        Text('Manage all client orders and update their status.',
                            style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${orders.length} Orders',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Search & Filter Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.inter(color: context.themeTextDark),
                    decoration: InputDecoration(
                      hintText: 'Search by Name, Email, or Gig Title...',
                      hintStyle: GoogleFonts.inter(color: context.themeTextLight),
                      prefixIcon: Icon(Icons.search, color: context.themeTextLight),
                      filled: true,
                      fillColor: context.themeSurface,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.themeBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Status Tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _statuses.map((status) {
                        final isSelected = _selectedStatus == status;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedStatus = status),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primary : context.themeSurface,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: isSelected ? AppTheme.primary : context.themeBorder, width: 1.5),
                            ),
                            child: Text(
                              status == 'All' ? 'All Orders' : status.replaceAll('_', ' ').toUpperCase(),
                              style: GoogleFonts.inter(
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected ? Colors.white : context.themeTextLight,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              if (orders.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, size: 64, color: AppTheme.textMuted.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text('No orders found matching your search.', style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: context.themeSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: context.themeBorder),
                    boxShadow: [
                      BoxShadow(color: context.isDarkMode ? Colors.transparent : Colors.black.withOpacity(0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SelectionArea(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: context.themeBorder.withOpacity(0.5)),
                      itemBuilder: (context, index) {
                        return AdminOrderListItem(order: orders[index]);
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
