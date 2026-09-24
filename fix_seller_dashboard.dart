import 'dart:io';

void main() {
  final file = File('lib/screens/seller_dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  // 1. Add timer code to _buildOrderCard
  // We need to insert the countdown timer if status is 'in_progress'
  final oldCardTop = '''
                    Text(order.gigTitle, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                    Text('\${order.packageName} Package • \\\$\${order.price.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ],
''';
  final newCardTop = '''
                    Text(order.gigTitle, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                    Text('\${order.packageName} Package • \\\$\${order.price.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: order.statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(order.statusLabel.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: order.statusColor)),
              ),
            ],
          ),
          if (order.status == 'in_progress' && order.startedAt != null) ...[
            const SizedBox(height: 12),
            _buildCountdownTimer(context, order.startedAt!, order.deliveryDays),
          ],
          if (order.status == 'revision') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Revision Requested', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.red.shade800, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(order.revisionNote.isNotEmpty ? order.revisionNote : 'The buyer has requested modifications.', style: GoogleFonts.inter(color: Colors.red.shade800, fontSize: 13)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
''';
  
  // Wait, I need to be careful with replacing. It's safer to replace the whole Column or parts of it.
  
  // Let's replace _buildSellerAction first
  final oldAction = '''
  Widget _buildSellerAction(BuildContext context, OrderModel order) {
    if (order.status == 'pending_payment') {
      return _buildLabel(const Color(0xFFDC2626), const Color(0xFFFEF2F2), const Color(0xFFFECACA), 'Waiting for Payment (Escrow)');
    } else if (order.status == 'requirements') {
      return _buildButton(context, AppTheme.primary, 'Start Work', () {
        FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': 'in_progress'});
      });
    } else if (order.status == 'in_progress') {
      return _buildButton(context, const Color(0xFF8B5CF6), 'Deliver Work', () {
        _showDeliveryModal(context, order);
      });
    } else if (order.status == 'delivered') {
      return _buildLabel(const Color(0xFFD97706), const Color(0xFFFEF3C7), const Color(0xFFFDE68A), 'Waiting for Client Approval');
    } else if (order.status == 'completed') {
      return _buildLabel(const Color(0xFF059669), const Color(0xFFD1FAE5), const Color(0xFFA7F3D0), 'Order Completed');
    } else if (order.status == 'cancelled') {
      return _buildLabel(const Color(0xFFDC2626), const Color(0xFFFEF2F2), const Color(0xFFFECACA), 'Order Cancelled');
    }
    return const SizedBox();
  }
''';
  final newAction = '''
  Widget _buildSellerAction(BuildContext context, OrderModel order) {
    if (order.status == 'pending_payment') {
      return _buildLabel(const Color(0xFFDC2626), const Color(0xFFFEF2F2), const Color(0xFFFECACA), 'Waiting for Payment (Escrow)');
    } else if (order.status == 'requirements') {
      return _buildButton(context, AppTheme.primary, 'Start Work', () {
        FirebaseFirestore.instance.collection('orders').doc(order.id).update({
          'status': 'in_progress',
          'startedAt': FieldValue.serverTimestamp(),
        });
      });
    } else if (order.status == 'in_progress' || order.status == 'revision') {
      return _buildButton(context, const Color(0xFF8B5CF6), 'Deliver Work', () {
        _showDeliveryModal(context, order);
      });
    } else if (order.status == 'delivered') {
      return _buildLabel(const Color(0xFFD97706), const Color(0xFFFEF3C7), const Color(0xFFFDE68A), 'Waiting for Client Approval');
    } else if (order.status == 'completed') {
      return _buildLabel(const Color(0xFF059669), const Color(0xFFD1FAE5), const Color(0xFFA7F3D0), 'Order Completed');
    } else if (order.status == 'cancelled') {
      return _buildLabel(const Color(0xFFDC2626), const Color(0xFFFEF2F2), const Color(0xFFFECACA), 'Order Cancelled');
    }
    return const SizedBox();
  }
''';

  content = content.replaceFirst(oldAction, newAction);

  // Delivery Modal
  final oldModal = '''
  void _showDeliveryModal(BuildContext context, OrderModel order) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Deliver Work', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Provide a link to your completed files (Google Drive, Dropbox, etc.) or write a delivery note.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            TextField(
              controller: noteCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Here is the link to the completed files...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (noteCtrl.text.trim().isEmpty) return;
              Navigator.pop(c);
              await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                'status': 'delivered',
                'deliveryNote': noteCtrl.text.trim(),
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work Delivered Successfully!')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Submit Delivery'),
          ),
        ],
      ),
    );
  }
''';
  final newModal = '''
  void _showDeliveryModal(BuildContext context, OrderModel order) {
    final linkCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: context.themeCard,
        title: Text('Deliver Work', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Provide a link to your completed files (Google Drive, Dropbox, etc.) and write a delivery message.', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
              const SizedBox(height: 16),
              Text('Delivery Link (Required)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: context.themeTextDark)),
              const SizedBox(height: 8),
              TextField(
                controller: linkCtrl,
                style: TextStyle(color: context.themeTextDark),
                decoration: InputDecoration(
                  hintText: 'https://...',
                ),
              ),
              const SizedBox(height: 16),
              Text('Message', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: context.themeTextDark)),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                maxLines: 4,
                style: TextStyle(color: context.themeTextDark),
                decoration: InputDecoration(
                  hintText: 'Here is the completed work...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (linkCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery link is required'), backgroundColor: Colors.red));
                return;
              }
              Navigator.pop(c);
              await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                'status': 'delivered',
                'deliveryLink': linkCtrl.text.trim(),
                'deliveryNote': noteCtrl.text.trim(),
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work Delivered Successfully!')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Submit Delivery'),
          ),
        ],
      ),
    );
  }
''';
  content = content.replaceFirst(oldModal, newModal);
  file.writeAsStringSync(content);
  print('Done replacements. Next we insert the countdown widget.');
}
