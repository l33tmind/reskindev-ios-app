import re

with open('lib/widgets/chat_bubble.dart', 'r') as f:
    content = f.read()

# Modify _buildTextBubble
old_wrap = """            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: ["""

new_wrap = """            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.replyToText != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border(left: BorderSide(color: isMe ? Colors.white : AppTheme.primary, width: 3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.replyToSender ?? '',
                          style: GoogleFonts.inter(
                            color: isMe ? Colors.white : AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          message.replyToText!,
                          style: GoogleFonts.inter(
                            color: isMe ? Colors.white : context.themeTextDark,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: ["""

if old_wrap in content:
    content = content.replace(old_wrap, new_wrap)
    
    # We opened a Column, so we need to close it.
    old_close = """              ],
            ),
          ),
          if (link != null)"""
          
    new_close = """                  ],
                ),
              ],
            ),
          ),
          if (link != null)"""
          
    content = content.replace(old_close, new_close)
    with open('lib/widgets/chat_bubble.dart', 'w') as f:
        f.write(content)
    print("Updated ChatBubble for replies")
else:
    print("Could not find wrap in _buildTextBubble")
