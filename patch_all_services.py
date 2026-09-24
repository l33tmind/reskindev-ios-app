import re

with open('lib/screens/all_services_screen.dart', 'r') as f:
    c = f.read()

# Add autoFocusSearch parameter
old_param = "  final String? initialCategory;\n  const AllServicesScreen({super.key, this.initialCategory});"
new_param = "  final String? initialCategory;\n  final bool autoFocusSearch;\n  const AllServicesScreen({super.key, this.initialCategory, this.autoFocusSearch = false});"
c = c.replace(old_param, new_param)

# Add focus node
old_state = "  final TextEditingController _searchCtrl = TextEditingController();\n  String _searchQuery = '';\n  String? _selectedCategory;"
new_state = "  final TextEditingController _searchCtrl = TextEditingController();\n  final FocusNode _searchFocus = FocusNode();\n  String _searchQuery = '';\n  String? _selectedCategory;"
c = c.replace(old_state, new_state)

# Auto focus in initState
old_init = "  void initState() {\n    super.initState();\n    _selectedCategory = widget.initialCategory;\n  }"
new_init = "  void initState() {\n    super.initState();\n    _selectedCategory = widget.initialCategory;\n    if (widget.autoFocusSearch) {\n      Future.delayed(const Duration(milliseconds: 100), () => _searchFocus.requestFocus());\n    }\n  }"
c = c.replace(old_init, new_init)

# Dispose focus node
old_dispose = "    _searchCtrl.dispose();\n    super.dispose();"
new_dispose = "    _searchCtrl.dispose();\n    _searchFocus.dispose();\n    super.dispose();"
c = c.replace(old_dispose, new_dispose)

# Add focus node to TextField
old_tf = "              controller: _searchCtrl,\n              onChanged: (val) => setState(() => _searchQuery = val),"
new_tf = "              controller: _searchCtrl,\n              focusNode: _searchFocus,\n              onChanged: (val) => setState(() => _searchQuery = val),"
c = c.replace(old_tf, new_tf)

with open('lib/screens/all_services_screen.dart', 'w') as f:
    f.write(c)
