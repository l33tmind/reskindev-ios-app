import re

with open('lib/screens/my_orders_screen.dart', 'r') as f:
    content = f.read()

# Add buttons to _OrderDetailsSheet for Buyer
old_details = """                  if (order.status == 'delivered') ...[
                    const Divider(height: 32),
                    _buildDetailRow(context, 'Delivery Note', order.deliveryNote.isEmpty ? 'No note provided' : order.deliveryNote),
                    const SizedBox(height: 24),"""

new_details = """                  if (order.status == 'cancel_requested_by_freelancer') ...[
                    const Divider(height: 32),
                    Text('The seller requested to cancel this order.', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: ElevatedButton(
                      onPressed: () => FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': 'cancelled'}),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('Accept Cancellation'),
                    )),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: OutlinedButton(
                      onPressed: () => FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': 'in_progress'}),
                      child: const Text('Decline'),
                    )),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: TextButton(
                      onPressed: () => FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': 'disputed'}),
                      child: const Text('Involve Admin', style: TextStyle(color: Colors.grey)),
                    )),
                  ],
                  if (order.status == 'cancel_requested_by_buyer') ...[
                    const Divider(height: 32),
                    Text('Waiting for seller to accept cancellation.', style: GoogleFonts.inter(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ],
                  if (order.status == 'disputed') ...[
                    const Divider(height: 32),
                    Text('Order is currently in dispute. An admin will review it soon.', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                  if (order.status == 'in_progress' || order.status == 'requirements') ...[
                    const Divider(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': 'cancel_requested_by_buyer'}),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                        child: const Text('Request Cancellation'),
                      ),
                    ),
                  ],
                  if (order.status == 'delivered') ...[
                    const Divider(height: 32),
                    _buildDetailRow(context, 'Delivery Note', order.deliveryNote.isEmpty ? 'No note provided' : order.deliveryNote),
                    const SizedBox(height: 24),"""
content = content.replace(old_details, new_details)

with open('lib/screens/my_orders_screen.dart', 'w') as f:
    f.write(content)

print("Updated Resolution Center for Buyer")
