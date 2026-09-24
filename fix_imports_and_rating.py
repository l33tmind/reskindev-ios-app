with open('lib/widgets/workspace_timeline_modals.dart', 'r') as f:
    c = f.read()

import re

c = "import 'package:firebase_auth/firebase_auth.dart';\nimport '../theme.dart';\n" + c

star_class = """
class _StarRating extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRatingChanged;
  const _StarRating({required this.rating, required this.onRatingChanged});
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () => onRatingChanged(index + 1),
          child: Padding(
            padding: const EdgeInsets.only(right: 2.0),
            child: Icon(
              Icons.star_rounded,
              size: 28,
              color: (index < rating) ? Colors.amber : Colors.grey.shade300,
            ),
          ),
        );
      }),
    );
  }
}
"""

c = c.replace("class WorkspaceActionModals {", star_class + "class WorkspaceActionModals {")
c = c.replace("activeColor", "activeThumbColor")

with open('lib/widgets/workspace_timeline_modals.dart', 'w') as f:
    f.write(c)

