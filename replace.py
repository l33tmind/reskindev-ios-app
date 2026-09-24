import re

with open('lib/widgets/workspace_details_sheet.dart', 'r') as f:
    content = f.read()

with open('rewrite.dart', 'r') as f:
    replacement = f.read()

# find @override\n  Widget build(BuildContext context) { ... } before _buildTimelineStep
start = content.find('  @override\n  Widget build(BuildContext context) {')
end = content.find('  Widget _buildTimelineStep(BuildContext context, {')

if start != -1 and end != -1:
    new_content = content[:start] + replacement + '\n  ' + content[end:]
    with open('lib/widgets/workspace_details_sheet.dart', 'w') as f:
        f.write(new_content)
    print("Success")
else:
    print("Not found")
