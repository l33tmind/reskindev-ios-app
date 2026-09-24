with open('lib/screens/seller_profile_screen.dart', 'r') as f:
    content = f.read()

# 1. Update constructor
old_constructor = """class SellerProfileScreen extends StatefulWidget {
  final String sellerId;
  const SellerProfileScreen({super.key, required this.sellerId});"""

new_constructor = """class SellerProfileScreen extends StatefulWidget {
  final String sellerId;
  final String? fallbackName;
  final String? fallbackImage;
  const SellerProfileScreen({super.key, required this.sellerId, this.fallbackName, this.fallbackImage});"""
content = content.replace(old_constructor, new_constructor)

# 2. Update user fetch logic.
# The current body has FutureBuilder for user. We need to replace it with a custom method or complex FutureBuilder.
# I'll create a new class to hold the parsed user data.

# Actually, I'll rewrite the entire file since it's around 300 lines and much cleaner to just provide the full file.
