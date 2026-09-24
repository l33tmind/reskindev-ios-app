import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    content = f.read()

# Make sure to import user_status_indicator
if 'user_status_indicator.dart' not in content:
    content = content.replace("import 'package:provider/provider.dart';", "import 'package:provider/provider.dart';\nimport '../widgets/user_status_indicator.dart';")

old_title = """              child: widget.targetUserAvatar.isEmpty
                  ? Icon(Icons.person, color: AppTheme.primary, size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              widget.targetUserName,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: context.themeTextDark),
            ),"""

new_title = """              child: widget.targetUserAvatar.isEmpty
                  ? Icon(Icons.person, color: AppTheme.primary, size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.targetUserName,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: context.themeTextDark),
                ),
                UserStatusIndicator(userId: widget.targetUserId),
              ],
            ),"""
content = content.replace(old_title, new_title)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(content)

print("Added UserStatusIndicator to Chat UI")
