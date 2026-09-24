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
              ? Text('Requirements submitted:\n${order.projectDetails}', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight), maxLines: 3, overflow: TextOverflow.ellipsis)
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
          isActive: order.status == 'processing' || order.status == 'revision',
          isCompleted: ['delivered', 'completed'].contains(order.status),
          content: _isPastProcessing(order.status)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order is currently in progress.', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
                    if ((order.status == 'processing' || order.status == 'revision') && isSeller) ...[
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
        ),
      ],
    );
  }
