with open('lib/screens/home_screen.dart', 'r') as f:
    c = f.read()

old_cat = """        if (query == 'mobile apps') catMatch = title.contains('app');
        else if (query == 'web dev') catMatch = title.contains('web');
        else if (query == 'ui design') catMatch = title.contains('design') || title.contains('ui');
        else if (query == 'backend') catMatch = title.contains('backend') || title.contains('server') || title.contains('database');
        else if (query == 'wordpress') catMatch = title.contains('wordpress') || title.contains('web');
        else if (query == 'seo') catMatch = title.contains('seo') || title.contains('marketing');
        else catMatch = title.contains(query);"""

new_cat = """        bool hasKw(String term) => g.keywords.any((k) => k.toLowerCase().contains(term));
        if (query == 'mobile apps') catMatch = title.contains('app') || hasKw('app') || hasKw('mobile');
        else if (query == 'web dev') catMatch = title.contains('web') || hasKw('web');
        else if (query == 'ui design') catMatch = title.contains('design') || title.contains('ui') || hasKw('design') || hasKw('ui');
        else if (query == 'backend') catMatch = title.contains('backend') || title.contains('server') || title.contains('database') || hasKw('backend');
        else if (query == 'wordpress') catMatch = title.contains('wordpress') || title.contains('web') || hasKw('wordpress');
        else if (query == 'seo') catMatch = title.contains('seo') || title.contains('marketing') || hasKw('seo');
        else catMatch = title.contains(query) || hasKw(query);"""

c = c.replace(old_cat, new_cat)
with open('lib/screens/home_screen.dart', 'w') as f:
    f.write(c)
