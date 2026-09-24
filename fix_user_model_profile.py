with open('lib/screens/seller_profile_screen.dart', 'r') as f:
    content = f.read()

bad = """      _loadedUser = UserModel(
        uid: widget.sellerId,
        email: '',
        displayName: widget.fallbackName ?? 'Verified Seller',
        photoUrl: widget.fallbackImage ?? '',
        role: 'freelancer',
        createdAt: DateTime.now(),
      );"""

good = """      _loadedUser = UserModel(
        uid: widget.sellerId,
        email: '',
        name: widget.fallbackName ?? 'Verified Seller',
        displayName: widget.fallbackName ?? 'Verified Seller',
        photoUrl: widget.fallbackImage ?? '',
        createdAt: DateTime.now(),
      );"""

content = content.replace(bad, good)
with open('lib/screens/seller_profile_screen.dart', 'w') as f:
    f.write(content)
