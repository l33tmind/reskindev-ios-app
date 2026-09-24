import re

with open('ios/Runner/Info.plist', 'r') as f:
    c = f.read()

if "ITSAppUsesNonExemptEncryption" not in c:
    c = c.replace("</dict>\n</plist>", "\t<key>ITSAppUsesNonExemptEncryption</key>\n\t<false/>\n</dict>\n</plist>")
    with open('ios/Runner/Info.plist', 'w') as f:
        f.write(c)
