import re

with open('lib/models/gig_model.dart', 'r') as f:
    content = f.read()

# Add category to fields
old_fields = """  final String title;
  final String slug;
  final String description;"""
new_fields = """  final String title;
  final String slug;
  final String category;
  final String description;"""
content = content.replace(old_fields, new_fields)

# Add to constructor
old_constructor = """    required this.title,
    this.slug = '',
    required this.description,"""
new_constructor = """    required this.title,
    this.slug = '',
    this.category = '',
    required this.description,"""
content = content.replace(old_constructor, new_constructor)

# Add to fromFirestore
old_fromMap = """      title: data['title'] ?? '',
      slug: data['slug'] ?? '',
      description: data['description'] ?? '',"""
new_fromMap = """      title: data['title'] ?? '',
      slug: data['slug'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',"""
content = content.replace(old_fromMap, new_fromMap)

# Add to toMap
old_toMap = """      'title': title,
      'slug': slug.isNotEmpty ? slug : _generateSlug(title),
      'description': description,"""
new_toMap = """      'title': title,
      'slug': slug.isNotEmpty ? slug : _generateSlug(title),
      'category': category,
      'description': description,"""
content = content.replace(old_toMap, new_toMap)

with open('lib/models/gig_model.dart', 'w') as f:
    f.write(content)

print("Added category to GigModel")
