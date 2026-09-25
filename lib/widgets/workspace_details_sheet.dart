import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../models/order_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'workspace_timeline_modals.dart';

class WorkspaceDetailsSheet extends StatelessWidget {
  final String orderId;
  final bool isSeller;
  final String chatId;

  const WorkspaceDetailsSheet({
    super.key,
    required this.orderId,
    required this.isSeller,
    required this.chatId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            color: context.themeBackground,
            height: 200,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final order = OrderModel.fromFirestore(snapshot.data!);
        return Container(
      decoration: BoxDecoration(
        color: context.themeBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: context.themeBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Text('Workspace Details', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: context.themeTextDark)),
          const SizedBox(height: 16),
          
          // Gig Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.gigTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextDark)),
                    const SizedBox(height: 4),
                    Text('\$${order.price}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Order ID
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order ID', style: GoogleFonts.inter(color: context.themeTextLight)),
              Text(order.id != null ? '#${order.id!.length > 6 ? order.id!.substring(0,6).toUpperCase() : order.id!.toUpperCase()}' : '#', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextDark)),
            ],
          ),
          const SizedBox(height: 24),
          
          Text('Order Timeline', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.themeTextDark)),
          const SizedBox(height: 16),
          
          // Timeline Stepper
          WorkspaceTimeline(order: order, isSeller: isSeller, chatId: chatId),
        ],
      ),
    );
      },
    );
  }
  Widget _buildPlaceholder() {
    return Container(
      width: 80,
      height: 60,
      color: Colors.grey.withValues(alpha: 0.2),
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }
}

class WorkspaceTimeline extends StatelessWidget {
  final OrderModel order;
  final bool isSeller;
  final String chatId;
  
  const WorkspaceTimeline({
    super.key, 
    required this.order,
    required this.isSeller,
    required this.chatId,
  });

  bool _isPastProcessing(String status) {
    return ['processing', 'in_progress', 'delivered', 'completed', 'revision'].contains(status);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step 1: Payment (Always completed)
        _buildTimelineStep(
          context,
          title: 'Payment Secured',
          isActive: true,
          isCompleted: true,
          content: Text('Funds of \$${order.price} are held in escrow.', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
        ),
        
        // Step 2: Requirements
        _buildTimelineStep(
          context,
          title: 'Requirements',
          isActive: order.status == 'requirements',
          isCompleted: order.projectDetails.isNotEmpty,
          content: order.projectDetails.isNotEmpty
              ? Text('Requirements submitted:\n${order.projectDetails}', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight), maxLines: 20, overflow: TextOverflow.ellipsis)
              : (order.status == 'requirements' && !isSeller
                  ? ElevatedButton(
                      onPressed: () => WorkspaceActionModals.showSubmitRequirements(context, order, chatId),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, minimumSize: const Size(120, 36)),
                      child: const Text('Submit Requirements'))
                  : null),
        ),

        // Step 3: Processing
        _buildTimelineStep(
          context,
          title: 'Processing',
          isActive: order.status == 'processing' || order.status == 'in_progress' || order.status == 'revision',
          isCompleted: ['delivered', 'completed'].contains(order.status),
          content: _isPastProcessing(order.status)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order is currently in progress.', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
                    if ((order.status == 'processing' || order.status == 'in_progress' || order.status == 'revision') && isSeller) ...[
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => WorkspaceActionModals.showDeliverWork(context, order, chatId),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                        child: const Text('Deliver Work'),
                      ),
                    ]
                  ],
                )
              : null,
        ),

        // Step 4: Delivered
        _buildTimelineStep(
          context,
          title: 'Delivery',
          isActive: order.status == 'delivered',
          isCompleted: order.status == 'completed',
          content: order.deliveryNote.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.deliveryNote, style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
                    const SizedBox(height: 8),
                    if (order.status == 'delivered' && !isSeller)
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => WorkspaceActionModals.showRevision(context, order, chatId),
                            child: const Text('Revision'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => WorkspaceActionModals.showAcceptDelivery(context, order, chatId),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                            child: const Text('Accept Delivery'),
                          ),
                        ],
                      )
                  ],
                )
              : (_isPastProcessing(order.status) ? Text('Waiting for review', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)) : null),
        ),

        // Step 5: Completed
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
        ),
      ],
    );
  }

  Widget _buildTimelineStep(BuildContext context, {
    required String title,
    required bool isActive,
    required bool isCompleted,
    Widget? content,
    bool isLast = false,
  }) {
    final color = isCompleted ? AppTheme.primary : (isActive ? AppTheme.primary : context.themeBorder);
    
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? AppTheme.primary : (isActive ? AppTheme.primary.withValues(alpha: 0.2) : context.themeSurface),
                  border: Border.all(color: color, width: 2),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : (isActive ? Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle))) : null),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: color,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.normal,
                      color: isActive || isCompleted ? context.themeTextDark : context.themeTextLight,
                    ),
                  ),
                  if (content != null) ...[
                    const SizedBox(height: 8),
                    content,
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
