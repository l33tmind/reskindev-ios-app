import re

with open('lib/models/order_model.dart', 'r') as f:
    content = f.read()

# 1. Add fields to OrderModel
old_fields = """  final String? publicReview;
  final String? privateFeedback;
  final double? overallRating;"""

new_fields = """  final String? publicReview;
  final String? privateFeedback;
  final double? overallRating;
  
  // Blind Review System
  final Map<String, dynamic>? buyerReview;
  final Map<String, dynamic>? sellerReview;
  final bool hasReview;
  final bool isReviewPublic;"""
content = content.replace(old_fields, new_fields)

# 2. Add to constructor
old_constructor = """    this.publicReview,
    this.privateFeedback,
    this.overallRating,
  }) : createdAt = createdAt ?? DateTime.now();"""

new_constructor = """    this.publicReview,
    this.privateFeedback,
    this.overallRating,
    this.buyerReview,
    this.sellerReview,
    this.hasReview = false,
    this.isReviewPublic = false,
  }) : createdAt = createdAt ?? DateTime.now();"""
content = content.replace(old_constructor, new_constructor)

# 3. Add to fromFirestore
old_fromMap = """      publicReview: d['publicReview'] as String?,
      privateFeedback: d['privateFeedback'] as String?,
      overallRating: (d['overallRating'] as num?)?.toDouble(),
    );"""

new_fromMap = """      publicReview: d['publicReview'] as String?,
      privateFeedback: d['privateFeedback'] as String?,
      overallRating: (d['overallRating'] as num?)?.toDouble(),
      buyerReview: d['buyerReview'] as Map<String, dynamic>?,
      sellerReview: d['sellerReview'] as Map<String, dynamic>?,
      hasReview: d['hasReview'] ?? false,
      isReviewPublic: d['isReviewPublic'] ?? false,
    );"""
content = content.replace(old_fromMap, new_fromMap)

# 4. Add to toMap
old_toMap = """      if (privateFeedback != null) 'privateFeedback': privateFeedback,
      if (overallRating != null) 'overallRating': overallRating,"""

new_toMap = """      if (privateFeedback != null) 'privateFeedback': privateFeedback,
      if (overallRating != null) 'overallRating': overallRating,
      if (buyerReview != null) 'buyerReview': buyerReview,
      if (sellerReview != null) 'sellerReview': sellerReview,
      'hasReview': hasReview,
      'isReviewPublic': isReviewPublic,"""
content = content.replace(old_toMap, new_toMap)

with open('lib/models/order_model.dart', 'w') as f:
    f.write(content)

print("Added Blind Review fields to OrderModel")
