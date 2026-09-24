import 'dart:io';

void main() {
  final file = File('lib/screens/admin_dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  if (!content.contains('AdminSupportTicketsView')) {
    content = content.replaceFirst(
      "import 'admin_coupons_view.dart';",
      "import 'admin_coupons_view.dart';\nimport 'admin_support_tickets_view.dart';"
    );
    
    // Add Mobile tab
    final oldMobile = "_MobileTab(label: 'Settings', isActive: _selectedIndex == 6, onTap: () => setState(() => _selectedIndex = 6)),";
    final newMobile = "_MobileTab(label: 'Settings', isActive: _selectedIndex == 6, onTap: () => setState(() => _selectedIndex = 6)),\n                  _MobileTab(label: 'Tickets', isActive: _selectedIndex == 7, onTap: () => setState(() => _selectedIndex = 7)),";
    content = content.replaceFirst(oldMobile, newMobile);
    
    // Add Desktop Sidebar item
    final oldSidebar = '''
                _SidebarItem(
                  icon: Icons.settings,
                  label: 'Settings',
                  isActive: _selectedIndex == 6,
                  onTap: () => setState(() => _selectedIndex = 6),
                ),
''';
    final newSidebar = '''
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
''';
    content = content.replaceFirst(oldSidebar, newSidebar);
    
    // Add logic
    final oldLogic = '''
                                : _selectedIndex == 5
                                    ? const AdminCouponsView()
                                    : _buildSettingsTab(),
''';
    final newLogic = '''
                                : _selectedIndex == 5
                                    ? const AdminCouponsView()
                                    : _selectedIndex == 6
                                        ? _buildSettingsTab()
                                        : const AdminSupportTicketsView(),
''';
    content = content.replaceFirst(oldLogic, newLogic);
  }

  file.writeAsStringSync(content);
}
