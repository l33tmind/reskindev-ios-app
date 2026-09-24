with open('lib/screens/gig_detail_screen.dart', 'r') as f:
    content = f.read()

# Replace _buildFiverrStickyBottomBar
old_sticky = """  Widget _buildFiverrStickyBottomBar(BuildContext context, GigModel gig, GigPackage pkg) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.themeSurface,
          boxShadow: [
            BoxShadow(color: context.isDarkMode ? Colors.transparent : Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
          ],
        ),
        child: _buildConfirmButton(context, pkg),
      ),
    );
  }"""

new_sticky = """  Widget _buildFiverrStickyBottomBar(BuildContext context, GigModel gig, GigPackage pkg) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.themeSurface,
          boxShadow: [
            BoxShadow(color: context.isDarkMode ? Colors.transparent : Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
          ],
        ),
        child: Row(
          children: [
            InkWell(
              onTap: () {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  context.push("/login");
                } else if (user.uid != gig.authorId) {
                  context.push('/chat/new', extra: {
                    'targetUserId': gig.authorId,
                    'targetUserName': gig.authorName.isNotEmpty ? gig.authorName : 'Verified Seller',
                    'targetUserAvatar': '', // Fallback if no avatar
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You cannot message yourself.')),
                  );
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: context.themeBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildConfirmButton(context, pkg)),
          ],
        ),
      ),
    );
  }"""

content = content.replace(old_sticky, new_sticky)

with open('lib/screens/gig_detail_screen.dart', 'w') as f:
    f.write(content)
print("Updated sticky bar")
