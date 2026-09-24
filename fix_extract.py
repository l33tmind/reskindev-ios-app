with open('lib/screens/gig_detail_screen.dart', 'r') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'String? _extractVideoId(String url) {' in line:
        # insert before "return null;" the "/vi/" check
        for j in range(i, len(lines)):
            if 'return null;' in lines[j]:
                lines.insert(j, "    } else if (url.contains('/vi/')) {\n      final id = url.split('/vi/')[1];\n      final slash = id.indexOf('/');\n      return slash != -1 ? id.substring(0, slash) : id;\n")
                break
        break

with open('lib/screens/gig_detail_screen.dart', 'w') as f:
    f.writelines(lines)
