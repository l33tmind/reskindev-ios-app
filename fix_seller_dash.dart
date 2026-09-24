import 'dart:io';

void main() {
  final file = File('lib/screens/seller_dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  final oldDropdownRow = '''
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: order.status,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'requirements', child: Text('Requirements')),
                    DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                    DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (val) {
                    if (val != null && val != order.status) {
                      FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': val});
                    }
                  },
                ),
              ),
            ],
          )
''';

  final newDropdownRow = '''
          Row(
            children: [
              Expanded(
                child: order.status == 'pending_payment'
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        border: Border.all(color: const Color(0xFFFECACA)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Waiting for Payment',
                        style: GoogleFonts.inter(color: const Color(0xFFDC2626), fontWeight: FontWeight.bold),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: order.status,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'requirements', child: Text('Requirements')),
                        DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                        DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                        DropdownMenuItem(value: 'completed', child: Text('Completed')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                      ],
                      onChanged: (val) {
                        if (val != null && val != order.status) {
                          FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': val});
                        }
                      },
                    ),
              ),
            ],
          )
''';

  content = content.replaceAll(oldDropdownRow, newDropdownRow);
  file.writeAsStringSync(content);
}
