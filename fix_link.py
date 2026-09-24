import re

with open('lib/widgets/chat_bubble.dart', 'r') as f:
    content = f.read()

def replace_text_message(m):
    original = m.group(0)
    
    new_method = """  Widget _buildTextBubble(BuildContext context) {
    final urlRegExp = RegExp(r'(https?:\/\/[^\s]+)');
    final match = urlRegExp.firstMatch(message.text);
    final link = match?.group(0);

    return Container(
      margin: EdgeInsets.only(top: isFirstInGroup ? 8 : 2),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? AppTheme.primary : context.themeSurface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isMe || !isFirstInGroup ? 16 : 16),
                topRight: Radius.circular(!isMe || !isFirstInGroup ? 16 : 16),
                bottomLeft: Radius.circular(isMe || !isLastInGroup ? 16 : 4),
                bottomRight: Radius.circular(!isMe || !isLastInGroup ? 16 : 4),
              ),
              border: isMe ? null : Border.all(color: context.themeBorder),
            ),
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 2),
                  child: Text(
                    message.text,
                    style: GoogleFonts.inter(
                      color: isMe ? Colors.white : context.themeTextDark,
                      fontSize: 15,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.createdAt != null
                          ? DateFormat('hh:mm a').format(message.createdAt!)
                          : 'Sending...',
                      style: GoogleFonts.inter(
                        color: isMe ? Colors.white.withOpacity(0.7) : context.themeTextLight,
                        fontSize: 10,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.createdAt == null
                            ? Icons.access_time
                            : (isRead ? Icons.done_all : Icons.check),
                        size: 14,
                        color: isRead ? Colors.blue.shade200 : Colors.white.withOpacity(0.7),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
          if (link != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 250),
                child: AnyLinkPreview(
                  link: link,
                  displayDirection: UIDirection.uiDirectionVertical,
                  showMultimedia: true,
                  bodyMaxLines: 3,
                  bodyTextOverflow: TextOverflow.ellipsis,
                  titleStyle: GoogleFonts.inter(
                    color: context.themeTextDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  bodyStyle: GoogleFonts.inter(
                    color: context.themeTextLight,
                    fontSize: 11,
                  ),
                  backgroundColor: context.themeSurface,
                  borderRadius: 12,
                  removeElevation: true,
                ),
              ),
            ),
        ],
      ),
    );
  }"""
    return new_method

content = re.sub(r'  Widget _buildTextBubble\(BuildContext context\) \{.*?(?=  Widget _buildImageBubble\(BuildContext context\))', replace_text_message, content, flags=re.DOTALL)

with open('lib/widgets/chat_bubble.dart', 'w') as f:
    f.write(content)

print("Updated chat_bubble")
