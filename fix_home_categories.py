import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

# 1. Add _dynamicCategories and fetch logic
old_state = """  bool _showAll = false;
  final GlobalKey _servicesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _syncRatingsOneTime();
  }"""

new_state = """  bool _showAll = false;
  final GlobalKey _servicesKey = GlobalKey();
  
  List<String> _dynamicCategories = [];

  @override
  void initState() {
    super.initState();
    _syncRatingsOneTime();
    _fetchCategories();
  }
  
  Future<void> _fetchCategories() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('admin_settings').doc('categories').get();
      if (doc.exists && doc.data()!.containsKey('list')) {
        setState(() {
          _dynamicCategories = List<String>.from(doc.data()!['list']);
        });
      }
    } catch (e) {
      debugPrint('Failed to load categories: $e');
    }
  }"""
content = content.replace(old_state, new_state)

# 2. Modify _CategoryChips to accept dynamic categories
old_chip = """class _CategoryChips extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;

  const _CategoryChips({
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  static const _categories = [
    ('All', Icons.apps_rounded),
    ('Mobile Apps', Icons.phone_android_rounded),
    ('Web Dev', Icons.web_rounded),
    ('UI Design', Icons.design_services_rounded),
    ('Backend', Icons.storage_rounded),
    ('WordPress', Icons.wordpress_rounded),
    ('SEO', Icons.trending_up_rounded),
  ];"""

new_chip = """class _CategoryChips extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final List<String> dynamicCategories;

  const _CategoryChips({
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.dynamicCategories,
  });"""
content = content.replace(old_chip, new_chip)

# 3. Modify ListView in _CategoryChips
old_list = """        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final cat = _categories[i];
          final isSelected = selectedCategory == cat.$1;
          return GestureDetector(
            onTap: () => onCategoryChanged(cat.$1),"""

new_list = """        itemCount: dynamicCategories.isEmpty ? 1 : dynamicCategories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final catName = i == 0 ? 'All' : dynamicCategories[i - 1];
          final catIcon = i == 0 ? Icons.apps_rounded : Icons.category_rounded;
          final isSelected = selectedCategory == catName;
          return GestureDetector(
            onTap: () => onCategoryChanged(catName),"""
content = content.replace(old_list, new_list)

# 4. Modify Row in _CategoryChips
old_row = """              child: Row(
                children: [
                  Icon(
                    cat.$2,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : context.themeTextLight,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cat.$1,"""

new_row = """              child: Row(
                children: [
                  Icon(
                    catIcon,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : context.themeTextLight,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    catName,"""
content = content.replace(old_row, new_row)

# 5. Pass dynamicCategories to _CategoryChips instances
content = content.replace("              child: _CategoryChips(\n                selectedCategory: _selectedCategory,\n                onCategoryChanged: (cat) => setState(() => _selectedCategory = cat),\n              ),", "              child: _CategoryChips(\n                selectedCategory: _selectedCategory,\n                onCategoryChanged: (cat) => setState(() => _selectedCategory = cat),\n                dynamicCategories: _dynamicCategories,\n              ),")

with open('lib/screens/home_screen.dart', 'w') as f:
    f.write(content)

print("Updated categories logic in home_screen")
