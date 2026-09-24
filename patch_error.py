with open('lib/screens/seller_dashboard_screen.dart', 'r') as f:
    c = f.read()

old_error = "if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error loading orders. Please try again.', style: GoogleFonts.inter(color: Colors.red))));"
new_error = "if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.red))));"
c = c.replace(old_error, new_error)
with open('lib/screens/seller_dashboard_screen.dart', 'w') as f:
    f.write(c)

with open('lib/screens/my_orders_screen.dart', 'r') as f:
    c2 = f.read()

old_builder = """        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final allOrders = (snap.data?.docs ?? [])"""

new_builder = """        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (snap.hasError) {
             return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.red)));
          }
          final allOrders = (snap.data?.docs ?? [])"""
c2 = c2.replace(old_builder, new_builder)
with open('lib/screens/my_orders_screen.dart', 'w') as f:
    f.write(c2)

