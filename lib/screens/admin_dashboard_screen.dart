import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:online_platform/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/settings_provider.dart';
import 'manage_services_view.dart';
import 'manage_pages_view.dart';
import 'admin_overview_view.dart';
import 'admin_users_view.dart';
import 'admin_coupons_view.dart';
import 'admin_support_tickets_view.dart';
import 'admin_orders_view.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();

    final isMobile = MediaQuery.of(context).size.width < 900;

    if (!auth.isAdmin) {
      return Scaffold(
        body: Center(
          child: Text('Access Denied', style: GoogleFonts.outfit(fontSize: 24)),
        ),
      );
    }

    if (isMobile) {
      return Scaffold(
        backgroundColor: context.themeBackground,
        appBar: AppBar(
          backgroundColor: context.themeSurface,
          title: Text('Admin Panel', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: context.themeTextDark)),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.themeTextDark),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            _buildNotificationIcon(context),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  _MobileTab(label: 'Stats', isActive: _selectedIndex == 0, onTap: () => setState(() => _selectedIndex = 0)),
                  _MobileTab(label: 'Orders', isActive: _selectedIndex == 1, onTap: () => setState(() => _selectedIndex = 1)),
                  _MobileTab(label: 'Users', isActive: _selectedIndex == 2, onTap: () => setState(() => _selectedIndex = 2)),
                  _MobileTab(label: 'Gigs', isActive: _selectedIndex == 3, onTap: () => setState(() => _selectedIndex = 3)),
                  _MobileTab(label: 'Pages', isActive: _selectedIndex == 4, onTap: () => setState(() => _selectedIndex = 4)),
                  _MobileTab(label: 'Coupons', isActive: _selectedIndex == 5, onTap: () => setState(() => _selectedIndex = 5)),
                  _MobileTab(label: 'Settings', isActive: _selectedIndex == 6, onTap: () => setState(() => _selectedIndex = 6)),
                  _MobileTab(label: 'Tickets', isActive: _selectedIndex == 7, onTap: () => setState(() => _selectedIndex = 7)),
                ],
              ),
            ),
          ),
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            const AdminOverviewView(),
            const AdminOrdersView(),
            const AdminUsersView(),
            const ManageServicesView(),
            const ManagePagesView(),
            const AdminCouponsView(),
            _buildSettingsTab(),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: _buildAppBar(context, auth),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: context.themeSurface,
              border: Border(right: BorderSide(color: context.themeBorder)),
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              children: [
                _SidebarItem(
                  icon: Icons.dashboard,
                  label: 'Overview',
                  isActive: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                _SidebarItem(
                  icon: Icons.receipt_long,
                  label: 'All Orders',
                  isActive: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                _SidebarItem(
                  icon: Icons.people,
                  label: 'Users',
                  isActive: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                _SidebarItem(
                  icon: Icons.design_services,
                  label: 'Manage Services',
                  isActive: _selectedIndex == 3,
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
                _SidebarItem(
                  icon: Icons.pages,
                  label: 'Manage Pages',
                  isActive: _selectedIndex == 4,
                  onTap: () => setState(() => _selectedIndex = 4),
                ),
                _SidebarItem(
                  icon: Icons.confirmation_number,
                  label: 'Coupons',
                  isActive: _selectedIndex == 5,
                  onTap: () => setState(() => _selectedIndex = 5),
                ),
                _SidebarItem(
                  icon: Icons.settings,
                  label: 'Settings',
                  isActive: _selectedIndex == 6,
                  onTap: () => setState(() => _selectedIndex = 6),
                ),
                _SidebarItem(
                  icon: Icons.support_agent,
                  label: 'Support Tickets',
                  isActive: _selectedIndex == 7,
                  onTap: () => setState(() => _selectedIndex = 7),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: _selectedIndex == 0
                ? const AdminOverviewView()
                : _selectedIndex == 1
                    ? const AdminOrdersView()
                    : _selectedIndex == 2
                        ? const AdminUsersView()
                        : _selectedIndex == 3
                            ? const ManageServicesView()
                            : _selectedIndex == 4
                                ? const ManagePagesView()
                                : _selectedIndex == 5
                                    ? const AdminCouponsView()
                                    : _selectedIndex == 6
                                        ? _buildSettingsTab()
                                        : const AdminSupportTicketsView(),
          ),
        ],
      ),
    );
  }



  Widget _buildSettingsTab() {
    final settings = context.watch<SettingsProvider>();
    final _urlController = TextEditingController(text: settings.youtubeUrl);
    final _titleController = TextEditingController(text: settings.heroTitle);
    final _descController = TextEditingController(text: settings.heroDescription);
    final _whatsappNumberController = TextEditingController(text: settings.whatsappNumber);
    final _appUrlController = TextEditingController(text: settings.featuredAppUrl);
    final _appNameController = TextEditingController(text: settings.featuredAppName);
    final _appDevController = TextEditingController(text: settings.featuredAppDeveloper);
    final _appIconUrlController = TextEditingController(text: settings.featuredAppIconUrl);
    
    final _footerEmailController = TextEditingController(text: settings.footerEmail);
    final _footerWebsiteController = TextEditingController(text: settings.footerWebsite);
    final _footerCopyrightController = TextEditingController(text: settings.footerCopyright);
    final _footerPhoneController = TextEditingController(text: settings.footerPhone);
    final _footerAddressController = TextEditingController(text: settings.footerAddress);
    final _footerDescController = TextEditingController(text: settings.footerDescription);

    final _servicesTitleController = TextEditingController(text: settings.servicesTitle);
    final _servicesSubtitleController = TextEditingController(text: settings.servicesSubtitle);

    final ValueNotifier<bool> _isFetching = ValueNotifier(false);

    return SingleChildScrollView(
      padding: EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Website Settings',
              style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: context.themeTextDark)),
          const SizedBox(height: 8),
          Text('Manage your website settings such as homepage videos and texts.',
              style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
          const SizedBox(height: 32),
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.themeSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.themeBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hero Section Settings', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                Text('Main Title', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'e.g. reskindev',
                    filled: true,
                    fillColor: context.themeSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Description', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'e.g. Buy or sell any service...',
                    filled: true,
                    fillColor: context.themeSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('YouTube Video URL', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _urlController,
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'https://www.youtube.com/watch?v=...',
                    filled: true,
                    fillColor: context.themeSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('WhatsApp Number', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _whatsappNumberController,
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'e.g. +1234567890',
                    filled: true,
                    fillColor: context.themeSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await context.read<SettingsProvider>().updateSettings(
                        youtubeUrl: _urlController.text,
                        heroTitle: _titleController.text,
                        heroDescription: _descController.text,
                        whatsappNumber: _whatsappNumberController.text,
                        featuredAppUrl: _appUrlController.text,
                        featuredAppName: _appNameController.text,
                        featuredAppDeveloper: _appDevController.text,
                        featuredAppIconUrl: _appIconUrlController.text,
                        servicesTitle: _servicesTitleController.text,
                        servicesSubtitle: _servicesSubtitleController.text,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved successfully!')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  ),
                  child: const Text('Save Settings'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.themeSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.themeBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Explore Services Section Settings', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                Text('Services Title', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _servicesTitleController,
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'e.g. Explore Services',
                    filled: true,
                    fillColor: context.themeSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Services Subtitle', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _servicesSubtitleController,
                  maxLines: 2,
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'e.g. Find the best services for your next project',
                    filled: true,
                    fillColor: context.themeSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await context.read<SettingsProvider>().updateSettings(
                        servicesTitle: _servicesTitleController.text,
                        servicesSubtitle: _servicesSubtitleController.text,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Services settings saved!')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  ),
                  child: const Text('Save Services Settings'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.themeSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.themeBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Featured App Banner (Hero Section)', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                Text('App Name', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _appNameController,
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'e.g. Habito - Habit Tracker',
                    filled: true,
                    fillColor: context.themeSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('App Developer', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _appDevController,
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'e.g. reskindev',
                    filled: true,
                    fillColor: context.themeSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('App Icon URL', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _appIconUrlController,
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'URL to the app icon image',
                    filled: true,
                    fillColor: context.themeSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Play Store URL', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _appUrlController,
                        style: GoogleFonts.inter(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'https://play.google.com/store/apps/details?id=...',
                          filled: true,
                          fillColor: context.themeSurface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ValueListenableBuilder<bool>(
                      valueListenable: _isFetching,
                      builder: (context, isFetching, child) {
                        return ElevatedButton.icon(
                          onPressed: isFetching ? null : () async {
                            final url = _appUrlController.text;
                            if (url.isEmpty || !url.contains('id=')) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid Play Store URL')));
                              return;
                            }
                            final uri = Uri.parse(url);
                            final appId = uri.queryParameters['id'];
                            if (appId == null) return;

                            _isFetching.value = true;
                            try {
                              // Replace localhost with your live API URL once deployed
                              final apiRes = await http.get(Uri.parse('http://localhost:3000/api/scrape?id=$appId'));
                              if (apiRes.statusCode == 200) {
                                final data = jsonDecode(apiRes.body);
                                _appNameController.text = data['title'] ?? '';
                                _appDevController.text = data['developer'] ?? '';
                                _appIconUrlController.text = data['iconUrl'] ?? '';
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App details fetched successfully!')));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch: ${apiRes.body}')));
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('API Error: Ensure the Node.js API is running on localhost:3000. $e')));
                            } finally {
                              _isFetching.value = false;
                            }
                          },
                          icon: isFetching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.auto_awesome, color: Colors.white),
                          label: Text(isFetching ? 'Fetching...' : 'Auto Fetch', style: const TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E392A),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await context.read<SettingsProvider>().updateSettings(
                        featuredAppUrl: _appUrlController.text,
                        featuredAppName: _appNameController.text,
                        featuredAppDeveloper: _appDevController.text,
                        featuredAppIconUrl: _appIconUrlController.text,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App banner settings saved!')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  ),
                  child: const Text('Save App Settings'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.themeSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.themeBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Footer Settings', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                Text('Contact Email', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _footerEmailController,
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'e.g. support@hireappdeveloper.com',
                    filled: true,
                    fillColor: context.themeSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Contact Phone', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _footerPhoneController,
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'e.g. +880123456789',
                    filled: true,
                    fillColor: context.themeSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Contact Address', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _footerAddressController,
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'e.g. Dhaka, Bangladesh',
                    filled: true,
                    fillColor: context.themeSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Website URL', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _footerWebsiteController,
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'e.g. hireappdeveloper.com',
                    filled: true,
                    fillColor: context.themeSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Footer Description', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _footerDescController,
                  maxLines: 2,
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'e.g. Professional app development...',
                    filled: true,
                    fillColor: context.themeSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Copyright Text', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _footerCopyrightController,
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'e.g. reskindev',
                    filled: true,
                    fillColor: context.themeSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.themeBorder)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await context.read<SettingsProvider>().updateSettings(
                        footerEmail: _footerEmailController.text,
                        footerWebsite: _footerWebsiteController.text,
                        footerCopyright: _footerCopyrightController.text,
                        footerPhone: _footerPhoneController.text,
                        footerAddress: _footerAddressController.text,
                        footerDescription: _footerDescController.text,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Footer settings saved!')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  ),
                  child: const Text('Save Footer Settings'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  void _showNotificationsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: context.themeBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: context.themeBorder, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                children: [
                  Text('New Orders', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: context.themeTextDark)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('orders').where(Filter.or(Filter('status', isEqualTo: 'pending_payment'), Filter('status', isEqualTo: 'pending'))).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator.adaptive());
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none_rounded, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.2)),
                          const SizedBox(height: 16),
                          Text('No new orders', style: GoogleFonts.inter(color: AppTheme.textMuted)),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 40),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = OrderModel.fromFirestore(docs[index]);
                      return Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.themeSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.themeBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(order.clientName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16))),
                                Text('\$${order.price.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AppTheme.primary)),
                              ],
                            ),
                            Text(order.gigTitle, style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: OutlinedButton(
                                    onPressed: () => _confirmCancelOrder(context, order),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFEF4444),
                                      side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await _updateOrderStatus(order, 'in_progress');
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B82F6),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    child: Text('Accept', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await _updateOrderStatus(order, 'completed');
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1BCA75),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    child: Text('Complete', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancelOrder(BuildContext context, OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.themeSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cancel Order?',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: context.themeTextDark),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel this order?',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: context.themeTextDark),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.themeBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.themeBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Client: ${order.clientName}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                  const SizedBox(height: 4),
                  Text('Service: ${order.gigTitle}', style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('Price: \$${order.price.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The client will be notified immediately about the cancellation.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444)),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Keep Order', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextLight)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: Text('Yes, Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateOrderStatus(order, 'cancelled');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #${order.id?.substring(0, 6) ?? ''} has been cancelled'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updateOrderStatus(OrderModel order, String newStatus) async {
    if (order.id == null) return;
    
    final oldStatus = order.status;
    await FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': newStatus});
    
    // Offline Escrow Logic: pending_payment -> requirements
    if (oldStatus == 'pending_payment' && newStatus == 'requirements') {
      try {
        // Notify Buyer
        await NotificationService.sendAndSaveNotification(
          userId: order.clientUid,
          title: 'Payment Secured! ✅',
          body: 'Reskindev has successfully held your escrow payment for ${order.gigTitle}. Please submit your requirements if you haven\'t already.',
        );
        
        // Notify Seller (Freelancer)
        if (order.authorId.isNotEmpty) {
          await NotificationService.sendAndSaveNotification(
            userId: order.authorId,
            title: 'Escrow Payment Received! 🎉',
            body: 'Reskindev has secured the funds for ${order.gigTitle}. You can now safely start working on this order!',
          );
        }
      } catch (e) {
        debugPrint('Error sending escrow notifications: $e');
      }
    } else {
      // Standard notification for other status updates
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(order.clientUid).get();
        final fcmToken = userDoc.data()?['fcmToken'];
        if (fcmToken != null) {
          await NotificationService.sendAndSaveNotification(
            userId: order.clientUid,
            title: 'Order Updated',
            body: 'Your order for ${order.gigTitle} is now $newStatus',
          );
        }
      } catch (e) {
        debugPrint('Error sending client notification: $e');
      }
    }

    // Trigger email via PHP
    try {
      await http.post(
        Uri.parse('https://reskindev.com/php/send_email.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': order.clientEmail,
          'clientName': order.clientName,
          'orderId': order.id,
          'status': newStatus,
          'gigTitle': order.gigTitle,
          'packageName': order.packageName,
          'price': order.price,
          'date': order.createdAt.toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('Email error: $e');
    }
  }

  Widget _buildNotificationIcon(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where(Filter.or(Filter('status', isEqualTo: 'pending_payment'), Filter('status', isEqualTo: 'pending')))
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.notifications_none_rounded, color: context.themeTextDark),
              onPressed: () {
                _showNotificationsBottomSheet(context);
              },
            ),
            if (count > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ap.AuthProvider auth) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: Container(
        decoration: BoxDecoration(
          color: context.themeSurface,
          border: Border(bottom: BorderSide(color: context.themeBorder)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.go('/'),
              child: Row(
                children: [
                  Image.asset('assets/logo.png', height: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Reskindev Admin',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: context.themeTextDark,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _buildNotificationIcon(context),
            const SizedBox(width: 24),
            TextButton.icon(
              onPressed: () => context.go('/'),
              icon: Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to Website'),
              style: TextButton.styleFrom(foregroundColor: context.themeTextLight),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _MobileTab({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : context.themeSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? AppTheme.primary : context.themeBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : context.themeTextLight,
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _SidebarItem({required this.icon, required this.label, required this.isActive, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isActive ? AppTheme.primary.withValues(alpha: 0.05) : Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: isActive ? AppTheme.primary : context.themeTextLight),
        title: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? AppTheme.primary : context.themeTextLight,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        onTap: onTap,
      ),
    );
  }
}

class AdminOrderListItem extends StatelessWidget {
  final OrderModel order;
  const AdminOrderListItem({super.key, required this.order});

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    if (order.id == null) return;
    try {
      await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
        'status': newStatus,
      });

      // Trigger push notification to client
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(order.clientUid).get();
        final fcmToken = userDoc.data()?['fcmToken'];
        if (fcmToken != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(order.clientUid)
              .collection('notifications')
              .add({
            'title': 'Order Completed! 🎉',
            'body': 'Your order for ${order.gigTitle} has been successfully completed.',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

          await NotificationService.sendPushNotification(
            fcmToken: fcmToken,
            title: 'Order Completed! 🎉',
            body: 'Your order for ${order.gigTitle} has been successfully completed.',
          );
        }
      } catch (e) {
        debugPrint('Error sending client notification: $e');
      }

      // Trigger Email via PHP Script
      try {
        await http.post(
          Uri.parse('https://reskindev.com/php/send_email.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': order.clientEmail,
            'clientName': order.clientName,
            'orderId': order.id,
            'status': newStatus,
            'gigTitle': order.gigTitle,
            'packageName': order.packageName,
            'price': order.price,
            'date': order.createdAt.toIso8601String(),
          }),
        );
      } catch (e) {
        debugPrint('Error sending email: $e');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.replaceAll('_', ' ')}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.primary,
          ),
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
    
    return InkWell(
      onTap: () {
        // Optional: Show order details dialog
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: isMobile 
          ? _buildMobileItem(context)
          : _buildDesktopItem(context),
      ),
    );
  }

  Widget _buildDesktopItem(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Client Info
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.clientName, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: context.themeTextDark)),
              const SizedBox(height: 4),
              Text(order.clientEmail, style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                _formatDate(order.createdAt),
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Order Info
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.gigTitle, 
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: context.themeTextDark),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      order.packageName.toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('\$${order.price.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: context.themeTextDark)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Status Dropdown
        SizedBox(
          width: 130,
          child: _buildStatusDropdown(context),
        ),
      ],
    );
  }

  Widget _buildMobileItem(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(order.clientName, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: context.themeTextDark)),
            ),
            Text('\$${order.price.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primary)),
          ],
        ),
        const SizedBox(height: 4),
        Text('${order.gigTitle} (${order.packageName})', style: GoogleFonts.inter(fontSize: 14, color: context.themeTextDark, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDate(order.createdAt), style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
            SizedBox(width: 150, child: _buildStatusDropdown(context)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusDropdown(BuildContext context) {
    Widget dropdown = Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: order.statusColor.withValues(alpha: 0.3)),
        color: order.statusColor.withValues(alpha: 0.05),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: order.status,
          isDense: true,
          isExpanded: true,
          dropdownColor: context.themeSurface,
          icon: Icon(Icons.arrow_drop_down, size: 20, color: order.statusColor),
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: order.statusColor),
          onChanged: (val) {
            if (val != null) _updateStatus(context, val);
          },
          items: [
            'pending_payment',
            'requirements',
            'in_progress',
            'delivered',
            'completed',
            'cancelled',
          ].map((String value) {
            final color = _getStatusColor(value);
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value.split('_').map((e) => e[0].toUpperCase() + e.substring(1)).join(' '),
                style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
        ),
      ),
    );

    if (order.status == 'pending_payment') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ElevatedButton.icon(
            onPressed: () => _updateStatus(context, 'requirements'),
            icon: const Icon(Icons.credit_card, size: 14),
            label: const Text('Verify Payment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 8),
          dropdown,
        ],
      );
    }

    return dropdown;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_payment': return const Color(0xFFEF4444); // Red
      case 'in_progress': return const Color(0xFF3B82F6); // Blue
      case 'delivered': return const Color(0xFF8B5CF6); // Purple
      case 'completed': return const Color(0xFF1BCA75); // Green
      case 'cancelled': return const Color(0xFFEF4444); // Red
      default: return const Color(0xFFF59E0B); // Amber
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_getMonth(date.month)} ${date.year}';
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
