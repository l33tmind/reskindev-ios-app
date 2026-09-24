import re

with open('lib/widgets/workspace_timeline_modals.dart', 'r') as f:
    content = f.read()

# remove the } before showSellerReview and add it at the end
content = content.replace("  }\n}\n\n  static void showSellerReview", "  }\n\n  static void showSellerReview")

if not content.endswith("}\n"):
    content += "}\n"

with open('lib/widgets/workspace_timeline_modals.dart', 'w') as f:
    f.write(content)
