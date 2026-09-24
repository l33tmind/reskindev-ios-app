with open('lib/models/order_model.dart', 'r') as f:
    c = f.read()

import re

# Helper functions for robust parsing
old_factory = "  factory OrderModel.fromFirestore(DocumentSnapshot doc) {"
new_factory = """  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
  
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {"""

c = c.replace(old_factory, new_factory)

# Replace fields
c = c.replace("price: (d['price'] as num?)?.toDouble() ?? 0,", "price: _parseDouble(d['price']) ?? 0,")
c = c.replace("basePrice: (d['basePrice'] as num?)?.toDouble() ?? 0,", "basePrice: _parseDouble(d['basePrice']) ?? 0,")
c = c.replace("discountAmount: (d['discountAmount'] as num?)?.toDouble() ?? 0,", "discountAmount: _parseDouble(d['discountAmount']) ?? 0,")
c = c.replace("deliveryDays: (d['deliveryDays'] as num?)?.toInt() ?? 3,", "deliveryDays: _parseInt(d['deliveryDays']) ?? 3,")

c = c.replace("ratingCommunication: (d['ratingCommunication'] as num?)?.toDouble(),", "ratingCommunication: _parseDouble(d['ratingCommunication']),")
c = c.replace("ratingQuality: (d['ratingQuality'] as num?)?.toDouble(),", "ratingQuality: _parseDouble(d['ratingQuality']),")
c = c.replace("ratingDescribed: (d['ratingDescribed'] as num?)?.toDouble(),", "ratingDescribed: _parseDouble(d['ratingDescribed']),")
c = c.replace("overallRating: (d['overallRating'] as num?)?.toDouble(),", "overallRating: _parseDouble(d['overallRating']),")

c = c.replace("createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),", "createdAt: _parseDate(d['createdAt']) ?? DateTime.now(),")
c = c.replace("completedAt: (d['completedAt'] as Timestamp?)?.toDate(),", "completedAt: _parseDate(d['completedAt']),")
c = c.replace("startedAt: (d['startedAt'] as Timestamp?)?.toDate(),", "startedAt: _parseDate(d['startedAt']),")
c = c.replace("deliveredAt: (d['deliveredAt'] as Timestamp?)?.toDate(),", "deliveredAt: _parseDate(d['deliveredAt']),")

with open('lib/models/order_model.dart', 'w') as f:
    f.write(c)
