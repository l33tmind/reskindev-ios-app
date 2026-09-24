with open('lib/widgets/search_full_screen.dart', 'r') as f:
    c = f.read()

old_search = """      return g.title.toLowerCase().contains(query.toLowerCase()) ||
          g.description.toLowerCase().contains(query.toLowerCase()) ||
          g.tags.any((t) => t.toLowerCase().contains(query.toLowerCase()));"""
new_search = """      final q = query.toLowerCase();
      return g.title.toLowerCase().contains(q) ||
          g.description.toLowerCase().contains(q) ||
          g.category.toLowerCase().contains(q) ||
          g.keywords.any((k) => k.toLowerCase().contains(q));"""
c = c.replace(old_search, new_search)
with open('lib/widgets/search_full_screen.dart', 'w') as f:
    f.write(c)

with open('lib/widgets/search_bottom_sheet.dart', 'r') as f:
    c2 = f.read()

old_search2 = """                g.title.toLowerCase().contains(_query.toLowerCase()) ||
                g.category.toLowerCase().contains(_query.toLowerCase()))"""
new_search2 = """                g.title.toLowerCase().contains(_query.toLowerCase()) ||
                g.category.toLowerCase().contains(_query.toLowerCase()) ||
                g.keywords.any((k) => k.toLowerCase().contains(_query.toLowerCase())))"""
c2 = c2.replace(old_search2, new_search2)
with open('lib/widgets/search_bottom_sheet.dart', 'w') as f:
    f.write(c2)
