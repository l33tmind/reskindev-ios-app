import 'dart:io';

void main() {
  final file = File('lib/screens/my_orders_screen.dart');
  var content = file.readAsStringSync();
  
  // Remove the badly injected RatingDialog
  final badInjectStart = content.indexOf('class RatingDialog extends StatefulWidget');
  if (badInjectStart != -1) {
    content = content.substring(0, badInjectStart);
  }
  
  // Close the last class if needed
  if (!content.trim().endsWith('}')) {
    content += '\n}';
  }

  // Count braces. Since I might have deleted too much, let's just make sure the file ends with the end of _buildDetailRow
  final buildDetailRowStr = 'Widget _buildDetailRow(BuildContext context, String label, String value) {';
  final detailRowIdx = content.lastIndexOf(buildDetailRowStr);
  if (detailRowIdx != -1) {
     final blockEnd = content.indexOf('  }\n}', detailRowIdx);
     if (blockEnd != -1) {
         content = content.substring(0, blockEnd + 4);
     }
  }

  // Now properly append RatingDialog at the very end OUTSIDE ANY CLASS
  final ratingDialogCode = '''
class RatingDialog extends StatefulWidget {
  final OrderModel order;
  const RatingDialog({super.key, required this.order});

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double comms = 5.0;
  double quality = 5.0;
  double described = 5.0;
  final publicCtrl = TextEditingController();
  final privateCtrl = TextEditingController();
  bool submitting = false;

  Widget _buildStarRow(String title, double value, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
          Row(
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => onChanged(index + 1.0),
                child: Icon(
                  index < value ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber,
                  size: 28,
                ),
              );
            }),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF1BCA75).withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.check_circle_rounded, color: Color(0xFF1BCA75), size: 48),
                    ),
                    const SizedBox(height: 16),
                    Text('Order Completed!', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Please rate your experience with this freelancer.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildStarRow('Communication Level', comms, (v) => setState(() => comms = v)),
              _buildStarRow('Quality of Work', quality, (v) => setState(() => quality = v)),
              _buildStarRow('Service as Described', described, (v) => setState(() => described = v)),
              const SizedBox(height: 16),
              TextField(
                controller: publicCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Public Review',
                  hintText: 'Share your experience with others...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: privateCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Private Feedback (Optional)',
                  hintText: 'Only admin can see this...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submitting ? null : () async {
                    setState(() => submitting = true);
                    final overall = (comms + quality + described) / 3.0;
                    
                    // 1. Update Order
                    await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({
                      'status': 'completed',
                      'completedAt': FieldValue.serverTimestamp(),
                      'ratingCommunication': comms,
                      'ratingQuality': quality,
                      'ratingDescribed': described,
                      'overallRating': overall,
                      'publicReview': publicCtrl.text.trim(),
                      'privateFeedback': privateCtrl.text.trim(),
                    });

                    // 2. Update Gig aggregates
                    final gigRef = FirebaseFirestore.instance.collection('services').doc(widget.order.gigId);
                    await FirebaseFirestore.instance.runTransaction((tx) async {
                      final doc = await tx.get(gigRef);
                      if (doc.exists) {
                        final currentCount = (doc.data()?['reviewCount'] as num?)?.toInt() ?? 0;
                        final currentAvg = (doc.data()?['averageRating'] as num?)?.toDouble() ?? 0.0;
                        
                        final newCount = currentCount + 1;
                        final newAvg = ((currentAvg * currentCount) + overall) / newCount;
                        
                        tx.update(gigRef, {
                          'reviewCount': newCount,
                          'averageRating': newAvg,
                        });
                      }
                    });

                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1BCA75),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: submitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Review'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
''';

  content += '\n\n' + ratingDialogCode;
  
  file.writeAsStringSync(content);
}
