import re

with open('lib/router.dart', 'r') as f:
    c = f.read()

c = c.replace("initialCategory: state.uri.queryParameters['category'],", "initialCategory: state.uri.queryParameters['category'],\n          autoFocusSearch: state.uri.queryParameters['search'] == 'true',")

with open('lib/router.dart', 'w') as f:
    f.write(c)

