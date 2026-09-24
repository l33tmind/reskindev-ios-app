import re

with open('lib/screens/profile_screen.dart', 'r') as f:
    content = f.read()

old_header = """                    Text(
                      auth.email,
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),"""

new_header = """                    if (auth.username != null && auth.username!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '@${auth.username}',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      auth.email,
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),"""

if old_header in content:
    content = content.replace(old_header, new_header)
    with open('lib/screens/profile_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed profile header")
else:
    print("Could not find profile header block")
