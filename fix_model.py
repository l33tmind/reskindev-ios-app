with open('lib/models/chat_models.dart', 'r') as f:
    c = f.read()

old_fields = """      rating: data['rating'] as num?,
      comment: data['comment']?.toString(),
      price: data['price'] as num?,
      offerPrice: data['offerPrice'] as num?,
      offerDays: data['offerDays'] as int?,"""

new_fields = """      rating: data['rating'] != null ? num.tryParse(data['rating'].toString()) : null,
      comment: data['comment']?.toString(),
      price: data['price'] != null ? num.tryParse(data['price'].toString()) : null,
      offerPrice: data['offerPrice'] != null ? num.tryParse(data['offerPrice'].toString()) : null,
      offerDays: data['offerDays'] != null ? int.tryParse(data['offerDays'].toString()) : null,"""

c = c.replace(old_fields, new_fields)
with open('lib/models/chat_models.dart', 'w') as f:
    f.write(c)
