import re

with open('lib/widgets/order_chat_cards.dart', 'r') as f:
    c = f.read()

# Make sure imports are there
if "import 'workspace_details_sheet.dart';" not in c:
    c = c.replace("import 'package:google_fonts/google_fonts.dart';", "import 'package:google_fonts/google_fonts.dart';\nimport 'package:cloud_firestore/cloud_firestore.dart';\nimport '../models/order_model.dart';\nimport 'workspace_details_sheet.dart';")

old_btn = """                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text('View Gig'),"""

new_btn = """                    OutlinedButton.icon(
                      onPressed: () async {
                        if (message.orderId == null || message.orderId!.isEmpty) return;
                        
                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(child: CircularProgressIndicator()),
                        );
                        
                        try {
                          final doc = await FirebaseFirestore.instance.collection('orders').doc(message.orderId).get();
                          if (context.mounted) Navigator.pop(context); // pop loading
                          
                          if (doc.exists && context.mounted) {
                            final order = OrderModel.fromFirestore(doc);
                            // We need to know if current user is seller.
                            // The message model doesn't directly have this, but we can guess it or pass it.
                            // However, since we don't have isSeller easily available here without checking,
                            // we can check if the current user ID matches the order's authorId.
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            final isSeller = uid == order.authorId;
                            
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => WorkspaceDetailsSheet(
                                order: order,
                                isSeller: isSeller,
                                chatId: 'unknown', // We don't have chatId easily here, but that's okay for display
                              ),
                            );
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order not found')));
                          }
                        } catch (e) {
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text('View Order'),"""

c = c.replace(old_btn, new_btn)

with open('lib/widgets/order_chat_cards.dart', 'w') as f:
    f.write(c)
