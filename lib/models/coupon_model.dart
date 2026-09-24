import 'package:cloud_firestore/cloud_firestore.dart';

class CouponModel {
  final String id;
  final String code;
  final double discount;
  final DateTime? expiryDate;
  final int? usageLimit;
  final int usageCount;
  final List<String> targetedUsers; // Emails of users who can use this
  final bool isActive;

  CouponModel({
    required this.id,
    required this.code,
    required this.discount,
    this.expiryDate,
    this.usageLimit,
    this.usageCount = 0,
    this.targetedUsers = const [],
    this.isActive = true,
  });

  factory CouponModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CouponModel(
      id: doc.id,
      code: data['code'] ?? '',
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      usageLimit: data['usageLimit'] as int?,
      usageCount: data['usageCount'] ?? 0,
      targetedUsers: List<String>.from(data['targetedUsers'] ?? []),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'code': code,
    'discount': discount,
    'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
    'usageLimit': usageLimit,
    'usageCount': usageCount,
    'targetedUsers': targetedUsers,
    'isActive': isActive,
  };
}
