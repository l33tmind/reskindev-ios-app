with open('lib/screens/all_services_screen.dart', 'r') as f:
    c = f.read()

old_search = "final matchesSearch = g.title.toLowerCase().contains(_searchQuery.toLowerCase());"
new_search = """      final searchLower = _searchQuery.toLowerCase();
      final matchTitle = g.title.toLowerCase().contains(searchLower);
      final matchCategory = g.category.toLowerCase().contains(searchLower);
      final matchKeywords = g.keywords.any((k) => k.toLowerCase().contains(searchLower));
      final matchesSearch = searchLower.isEmpty || matchTitle || matchCategory || matchKeywords;"""

c = c.replace(old_search, new_search)
with open('lib/screens/all_services_screen.dart', 'w') as f:
    f.write(c)
