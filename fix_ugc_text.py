import re

with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    content = f.read()

old_subtitle = """                                  subtitle: Text(
                                    'I declare that the media uploaded or linked above is my original work, and I have the rights to use it.',
                                    style: GoogleFonts.inter(fontSize: 12, color: context.themeTextDark),
                                  ),"""

new_subtitle = """                                  subtitle: Text(
                                    'I confirm this video is uploaded as "Unlisted" on YouTube. I acknowledge that I am submitting User-Generated Content (UGC) and warrant that I own all intellectual property rights to this video. I agree not to submit any copyrighted, objectionable, or abusive material. I grant Reskindev permission to embed this video and assume full legal liability for its content.',
                                    style: GoogleFonts.inter(fontSize: 12, color: context.themeTextDark),
                                  ),"""

if old_subtitle in content:
    content = content.replace(old_subtitle, new_subtitle)
    with open('lib/screens/gig_editor_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed UGC Text")
else:
    print("Could not find UGC subtitle block")
