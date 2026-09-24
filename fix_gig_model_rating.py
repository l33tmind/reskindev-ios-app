import re

with open('lib/models/gig_model.dart', 'r') as f:
    content = f.read()

# Find the return GigModel( block in fromFirestore
target = "    return GigModel(\n      id: doc.id,"
replacement = """    return GigModel(
      id: doc.id,
      averageRating: (data['rating'] as num?)?.toDouble() ?? (data['averageRating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? (data['reviews'] as num?)?.toInt() ?? 0,"""

if target in content:
    content = content.replace(target, replacement)
    with open('lib/models/gig_model.dart', 'w') as f:
        f.write(content)
    print("Fixed GigModel rating extraction")
else:
    print("Could not find target")
