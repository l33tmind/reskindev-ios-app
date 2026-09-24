with open('lib/widgets/chat_bubble.dart', 'r') as f:
    c = f.read()

# Replace bubble decoration
old_dec = """            decoration: BoxDecoration(
              color: isMe ? AppTheme.primary : context.themeSurface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isMe || !isFirstInGroup ? 16 : 16),
                topRight: Radius.circular(!isMe || !isFirstInGroup ? 16 : 16),
                bottomLeft: Radius.circular(isMe || !isLastInGroup ? 16 : 4),
                bottomRight: Radius.circular(!isMe || !isLastInGroup ? 16 : 4),
              ),
              border: isMe ? null : Border.all(color: context.themeBorder),
            ),"""

new_dec = """            decoration: BoxDecoration(
              color: isMe ? AppTheme.primary : context.themeSurface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : (isLastInGroup ? 4 : 18)),
                bottomRight: Radius.circular(!isMe ? 18 : (isLastInGroup ? 4 : 18)),
              ),
              border: isMe ? null : Border.all(color: context.themeBorder.withValues(alpha: 0.6)),
            ),"""
c = c.replace(old_dec, new_dec)

with open('lib/widgets/chat_bubble.dart', 'w') as f:
    f.write(c)
