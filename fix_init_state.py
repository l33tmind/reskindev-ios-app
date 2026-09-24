import re

with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    content = f.read()

old_init = """  @override
  void initState() {
    super.initState();
    final g = widget.gig;
    _titleCtrl = TextEditingController(text: g?.title ?? '');"""
new_init = """  @override
  void initState() {
    super.initState();
    _fetchCategories();
    final g = widget.gig;
    _selectedCategory = g?.category ?? '';
    _titleCtrl = TextEditingController(text: g?.title ?? '');"""
content = content.replace(old_init, new_init)

with open('lib/screens/gig_editor_screen.dart', 'w') as f:
    f.write(content)

print("Fixed initState")
