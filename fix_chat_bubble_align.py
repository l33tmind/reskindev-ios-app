import re

with open('lib/widgets/chat_bubble.dart', 'r') as f:
    content = f.read()

old_code = """  Widget _buildTextBubble(BuildContext context) {
    final urlRegExp = RegExp(r'(https?:\/\/[^\s]+)');
    final match = urlRegExp.firstMatch(message.text);
    final link = match?.group(0);

    return Container(
      margin: EdgeInsets.only(top: isFirstInGroup ? 8 : 2),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),"""

new_code = """  Widget _buildTextBubble(BuildContext context) {
    final urlRegExp = RegExp(r'(https?:\/\/[^\s]+)');
    final match = urlRegExp.firstMatch(message.text);
    final link = match?.group(0);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: isFirstInGroup ? 8 : 2),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),"""

content = content.replace(old_code, new_code)
with open('lib/widgets/chat_bubble.dart', 'w') as f:
    f.write(content)

print("Fixed ChatBubble alignment by adding width: double.infinity")
