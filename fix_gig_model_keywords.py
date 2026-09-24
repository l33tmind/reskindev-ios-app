with open('lib/models/gig_model.dart', 'r') as f:
    c = f.read()

c = c.replace("final List<String> tags;", "final List<String> keywords;")
c = c.replace("this.tags = const [],", "this.keywords = const [],")
c = c.replace("tags: List<String>.from(data['tags'] ?? []),", "keywords: List<String>.from(data['keywords'] ?? data['tags'] ?? []),")
c = c.replace("'tags': tags,", "'keywords': keywords,\n      'tags': keywords, // keep tags for backward compatibility")

with open('lib/models/gig_model.dart', 'w') as f:
    f.write(c)
