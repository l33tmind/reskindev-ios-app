import re

with open('lib/models/page_model.dart', 'r') as f:
    c = f.read()

# Replace data['page_type'] with (data['pageType'] ?? data['page_type'])
c = c.replace("data['page_type'] ?? 'link'", "(data['pageType'] ?? data['page_type']) ?? 'link'")
c = c.replace("data['link_url'] ?? ''", "(data['linkUrl'] ?? data['link_url']) ?? ''")
c = c.replace("data['open_in_new_tab'] ?? true", "(data['openInNewTab'] ?? data['open_in_new_tab']) ?? true")
c = c.replace("data['is_visible'] ?? true", "(data['isVisible'] ?? data['is_visible']) ?? true")

with open('lib/models/page_model.dart', 'w') as f:
    f.write(c)
