import re

with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    content = f.read()

# Add _categories and _selectedCategory
old_state = """  bool _isSaving = false;
  String _status = 'active';"""
new_state = """  bool _isSaving = false;
  String _status = 'active';
  String _selectedCategory = '';
  List<String> _categories = [];"""
content = content.replace(old_state, new_state)

# Fetch categories in initState
old_init = """    super.initState();
    final g = widget.initialGig;

    _titleCtrl = TextEditingController(text: g?.title ?? '');"""
new_init = """    super.initState();
    _fetchCategories();
    final g = widget.initialGig;

    _selectedCategory = g?.category ?? '';
    _titleCtrl = TextEditingController(text: g?.title ?? '');"""
content = content.replace(old_init, new_init)

# _fetchCategories method
fetch_method = """  Future<void> _fetchCategories() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('admin_settings').doc('categories').get();
      if (doc.exists && doc.data()!.containsKey('list')) {
        setState(() {
          _categories = List<String>.from(doc.data()!['list']);
          if (_selectedCategory.isEmpty && _categories.isNotEmpty) {
            _selectedCategory = _categories.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load categories: $e');
    }
  }

  """
if "_fetchCategories" not in content:
    content = content.replace("  Future<void> _pickAndUploadImage() async {", fetch_method + "Future<void> _pickAndUploadImage() async {")

# Add category dropdown UI
old_title_ui = """                _buildTextField(_titleCtrl, 'Gig Title', 'e.g. I will design a modern logo', required: true),
                const SizedBox(height: 16),
                _buildTextField(_descCtrl, 'Description (HTML supported)', 'Explain your service...', maxLines: 5, required: true),"""
new_title_ui = """                _buildTextField(_titleCtrl, 'Gig Title', 'e.g. I will design a modern logo', required: true),
                const SizedBox(height: 16),
                if (_categories.isNotEmpty) ...[
                  const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _categories.contains(_selectedCategory) ? _selectedCategory : (_categories.isNotEmpty ? _categories.first : null),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: context.themeSurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                _buildTextField(_descCtrl, 'Description (HTML supported)', 'Explain your service...', maxLines: 5, required: true),"""
content = content.replace(old_title_ui, new_title_ui)

# Update _save to pass category
old_save = """      final newGig = GigModel(
        id: widget.initialGig?.id ?? '',
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),"""
new_save = """      final newGig = GigModel(
        id: widget.initialGig?.id ?? '',
        title: _titleCtrl.text.trim(),
        category: _selectedCategory,
        description: _descCtrl.text.trim(),"""
content = content.replace(old_save, new_save)

with open('lib/screens/gig_editor_screen.dart', 'w') as f:
    f.write(content)

print("Added category to GigEditorScreen")
