with open('lib/widgets/workspace_timeline_modals.dart', 'r') as f:
    c = f.read()

import re

# First, define a reusable widget for 5-star rating row
rating_widget = """
class _StarRating extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRatingChanged;
  const _StarRating({required this.rating, required this.onRatingChanged});
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () => onRatingChanged(index + 1),
          child: Icon(
            Icons.star_rounded,
            size: 28,
            color: (index < rating) ? Colors.amber : Colors.grey.shade300,
          ),
        );
      }),
    );
  }
}
"""

if "_StarRating" not in c:
    # insert at the top after imports
    lines = c.split('\n')
    for i, line in enumerate(lines):
        if line.startswith('class WorkspaceTimelineModals'):
            lines.insert(i, rating_widget)
            break
    c = '\n'.join(lines)

def replace_modal(is_seller):
    if is_seller:
        func_sig = "static void showSellerReview(BuildContext context, OrderModel order, String chatId) {"
        title = "Review Buyer"
        submit_text = "Submit Review"
        action_type = "seller_review_submitted"
        action_msg = "The seller has submitted a review for this order."
    else:
        func_sig = "static void showAcceptAndReview(BuildContext context, OrderModel order) {"
        title = "Accept & Review"
        submit_text = "Accept & Submit"
        action_type = "order_completed"
        action_msg = "The buyer has accepted the delivery and payment has been transferred!"
        
    start_idx = c.find(func_sig)
    if start_idx == -1: return
    
    # find the end of the function (matching brace for showDialog)
    # Actually just replace the whole function using regex or carefully
    pass

# We will just rewrite the whole file since it's cleaner to use a python script to replace the functions
