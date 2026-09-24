import re

with open('lib/screens/gig_detail_screen.dart', 'r') as f:
    c = f.read()

# The function to strip looks exactly like this, including its body:
def strip_injected_code(text):
    # Regex to find the whole block from void _showReportDialog to the end of _showBlockDialog
    # We injected:
    # void _showReportDialog(...) { ... }
    # void _showBlockDialog(...) { ... }
    # }
    
    # Let's just use regex to remove everything from 'void _showReportDialog' to 'child: const Text('Block'),\n          ),\n        ],\n      );\n    },\n  );\n}'
    
    pattern = re.compile(r'void _showReportDialog\(BuildContext context, GigModel gig\) \{.*?\n  \);\n\}', re.DOTALL)
    c_cleaned = re.sub(pattern, '', text)
    
    pattern2 = re.compile(r'void _showBlockDialog\(BuildContext context, GigModel gig\) \{.*?\n  \);\n\}', re.DOTALL)
    c_cleaned2 = re.sub(pattern2, '', c_cleaned)
    return c_cleaned2

c = strip_injected_code(c)

with open('lib/screens/gig_detail_screen.dart', 'w') as f:
    f.write(c)

