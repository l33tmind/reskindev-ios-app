import re

with open('lib/widgets/workspace_details_sheet.dart', 'r') as f:
    content = f.read()

old_step5 = """        // Step 5: Completed
        _buildTimelineStep(
          context,
          title: 'Completed',
          isActive: order.status == 'completed',
          isCompleted: order.status == 'completed',
          isLast: true,
          content: order.buyerReview != null
              ? Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Row(
                            children: List.generate(
                              5,
                              (index) => Icon(
                                Icons.star_rounded,
                                color: index < (order.buyerReview!['rating'] as num? ?? 5.0).toInt() ? Colors.amber : Colors.grey.withValues(alpha: 0.3),
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('${order.buyerReview!['rating'] ?? 5.0}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
                        ],
                      ),
                      if (order.buyerReview!['comment'] != null)
                        Text('"${order.buyerReview!['comment']}"', style: GoogleFonts.inter(fontSize: 12, color: context.themeTextDark, fontStyle: FontStyle.italic)),
                    ],
                  ),
                )
              : (order.status == 'completed' ? Text('Funds Released', style: GoogleFonts.inter(fontSize: 13, color: Colors.green)) : null),
        ),"""

new_step5 = """        // Step 5: Completed
        _buildTimelineStep(
          context,
          title: 'Completed',
          isActive: order.status == 'completed',
          isCompleted: order.status == 'completed',
          isLast: true,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (order.buyerReview != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Buyer Review:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Row(
                            children: List.generate(
                              5,
                              (index) => Icon(
                                Icons.star_rounded,
                                color: index < (order.buyerReview!['rating'] as num? ?? 5.0).toInt() ? Colors.amber : Colors.grey.withValues(alpha: 0.3),
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('${order.buyerReview!['rating'] ?? 5.0}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
                        ],
                      ),
                      if (order.buyerReview!['comment'] != null)
                        Text('"${order.buyerReview!['comment']}"', style: GoogleFonts.inter(fontSize: 12, color: context.themeTextDark, fontStyle: FontStyle.italic)),
                    ],
                  ),
                )
              else if (order.status == 'completed')
                Text('Funds Released', style: GoogleFonts.inter(fontSize: 13, color: Colors.green)),
              
              if (order.status == 'completed' && isSeller && order.buyerReview != null && order.sellerReview == null)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Leave a Review', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.blue[800])),
                      const SizedBox(height: 4),
                      Text('The buyer has rated you. Rate your experience.', style: GoogleFonts.inter(fontSize: 12, color: Colors.blue[600])),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => WorkspaceActionModals.showSellerReview(context, order, chatId),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 36)),
                        child: const Text('Rate Buyer'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),"""

new_content = content.replace(old_step5, new_step5)
with open('lib/widgets/workspace_details_sheet.dart', 'w') as f:
    f.write(new_content)
