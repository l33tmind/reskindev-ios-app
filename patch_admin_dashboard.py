import re

with open('lib/screens/admin_dashboard_screen.dart', 'r') as f:
    c = f.read()

# Replace _buildStatusDropdown
old_func = """  Widget _buildStatusDropdown(BuildContext context) {
    return Container(
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
  }"""

new_func = """  Widget _buildStatusDropdown(BuildContext context) {
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
  }"""

c = c.replace(old_func, new_func)

with open('lib/screens/admin_dashboard_screen.dart', 'w') as f:
    f.write(c)

