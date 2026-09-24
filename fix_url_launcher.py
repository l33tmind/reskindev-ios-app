import re

with open('lib/screens/profile_screen.dart', 'r') as f:
    c = f.read()

old_logic = """                  if (isLink) {
                    final url = Uri.tryParse(page.linkUrl);
                    if (url != null && await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  } else {"""

new_logic = """                  if (isLink) {
                    if (page.linkUrl.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Link is empty. Please update it from the Admin Panel.')));
                      return;
                    }
                    final urlStr = page.linkUrl.startsWith('http') ? page.linkUrl : 'https://${page.linkUrl}';
                    final url = Uri.tryParse(urlStr);
                    if (url != null) {
                      try {
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        } else {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the link.')));
                        }
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid Link: $e')));
                      }
                    }
                  } else {"""

c = c.replace(old_logic, new_logic)

with open('lib/screens/profile_screen.dart', 'w') as f:
    f.write(c)
