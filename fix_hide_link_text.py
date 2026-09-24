import re

with open('lib/widgets/chat_bubble.dart', 'r') as f:
    content = f.read()

old_code = """  Widget _buildTextBubble(BuildContext context) {
    final urlRegExp = RegExp(r'(https?:\/\/[^\s]+)');
    final match = urlRegExp.firstMatch(message.text);
    final link = match?.group(0);"""

new_code = """  Widget _buildTextBubble(BuildContext context) {
    final urlRegExp = RegExp(r'(https?:\/\/[^\s]+)');
    final match = urlRegExp.firstMatch(message.text);
    final link = match?.group(0);
    final isOnlyLink = link != null && message.text.trim() == link;"""

content = content.replace(old_code, new_code)

old_wrap = """                Wrap(
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
                Row("""

new_wrap = """                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                if (!isOnlyLink)
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
                Row("""
content = content.replace(old_wrap, new_wrap)

with open('lib/widgets/chat_bubble.dart', 'w') as f:
    f.write(content)

print("Hid raw link text if it's only a link")
