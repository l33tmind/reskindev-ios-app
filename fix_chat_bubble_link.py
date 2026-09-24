import re

with open('lib/widgets/chat_bubble.dart', 'r') as f:
    content = f.read()

# Add import
if "import 'package:any_link_preview/any_link_preview.dart';" not in content:
    content = "import 'package:any_link_preview/any_link_preview.dart';\n" + content

# Replace _buildTextMessage
old_text = """    return Container(
      margin: EdgeInsets.only(top: isFirstInGroup ? 8 : 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : context.themeSurface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMe || !isLastInGroup ? 16 : 4),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : (!isLastInGroup ? 16 : 4)),
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
              children: ["""

new_text = """    final urlRegExp = RegExp(r'(https?:\/\/[^\s]+)');
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
                topLeft: Radius.circular(isMe || !isLastInGroup ? 16 : 4),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : (!isLastInGroup ? 16 : 4)),
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
                  children: ["""

if old_text in content:
    content = content.replace(old_text, new_text)

old_text_end = """              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageMessage(BuildContext context) {"""

new_text_end = """              ],
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
  }

  Widget _buildImageMessage(BuildContext context) {"""

if old_text_end in content:
    content = content.replace(old_text_end, new_text_end)

with open('lib/widgets/chat_bubble.dart', 'w') as f:
    f.write(content)

print("Updated chat_bubble.dart for links")
