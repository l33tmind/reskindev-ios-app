import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String? id;

  // Gig Info
  final String gigId;
  final String gigTitle;

  // Package Info
  final String packageId;   // 'basic', 'standard', 'premium'
  final String packageName;

  // Pricing
  final double price;        // Final paid amount
  final double basePrice;    // Original price before discount
  final double discountAmount;

  final int quantity;
  // Delivery
  final int deliveryDays;

  // Client (Buyer) Info — Web schema fields
  final String userId;       // UID of the client (Web: userId)
  final String userName;     // Client display name
  final String userEmail;    // Client email

  // Freelancer (Seller) Info
  final String authorId;     // UID of the freelancer

  // Order Details
  final String projectDetails;

  // Status: Web schema statuses
  // 'requirements' → 'in_progress' → 'delivered' → 'completed' | 'cancelled'
  final String status;

  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? startedAt;
  final DateTime? deliveredAt;
  final String deliveryNote;
  final String deliveryLink;
  final String revisionNote;
  
  // Rating & Review
  final double? ratingCommunication;
  final double? ratingQuality;
  final double? ratingDescribed;
  final String? publicReview;
  final String? privateFeedback;
  final double? overallRating;
  
  // Blind Review System
  final Map<String, dynamic>? buyerReview;
  final Map<String, dynamic>? sellerReview;
  final bool hasReview;
  final bool isReviewPublic;


  OrderModel({
    this.id,
    required this.gigId,
    required this.gigTitle,
    this.packageId = '',
    required this.packageName,
    required this.price,
    this.basePrice = 0,
    this.discountAmount = 0,
    this.quantity = 1,
    this.deliveryDays = 3,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.authorId = '',
    required this.projectDetails,
    this.status = 'requirements',
    DateTime? createdAt,
    this.completedAt,
    this.startedAt,
    this.deliveredAt,
    this.deliveryNote = '',
    this.deliveryLink = '',
    this.revisionNote = '',
    this.ratingCommunication,
    this.ratingQuality,
    this.ratingDescribed,
    this.publicReview,
    this.privateFeedback,
    this.overallRating,
    this.buyerReview,
    this.sellerReview,
    this.hasReview = false,
    this.isReviewPublic = false,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convenience getters for backward compatibility
  String get clientUid => userId;
  String get clientName => userName;
  String get clientEmail => userEmail;

  static double? _parseDouble(dynamic value) {
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

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    // Support both new (userId) and legacy (clientUid) field names
    final userId = d['userId'] as String? ??
        d['clientUid'] as String? ?? '';
    final userName = d['userName'] as String? ??
        d['clientName'] as String? ?? '';
    final userEmail = d['userEmail'] as String? ??
        d['clientEmail'] as String? ?? '';

    return OrderModel(
      id: doc.id,
      gigId: d['gigId'] ?? '',
      gigTitle: d['gigTitle'] ?? '',
      packageId: d['packageId'] ?? '',
      packageName: d['packageName'] ?? '',
      price: _parseDouble(d['price']) ?? 0,
      basePrice: _parseDouble(d['basePrice']) ?? 0,
      discountAmount: _parseDouble(d['discountAmount']) ?? 0,
      quantity: _parseInt(d['quantity']) ?? 1,
      deliveryDays: _parseInt(d['deliveryDays']) ?? 3,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      authorId: d['authorId'] ?? '',
      projectDetails: d['requirementsText'] ?? d['projectDetails'] ?? '',
      status: d['status'] ?? 'requirements',
      createdAt: _parseDate(d['createdAt']) ?? DateTime.now(),
      completedAt: _parseDate(d['completedAt']),
      startedAt: _parseDate(d['startedAt']),
      deliveredAt: _parseDate(d['deliveredAt']),
      deliveryNote: d['deliveryNote'] ?? '',
      deliveryLink: d['deliveryLink'] ?? '',
      revisionNote: d['revisionNote'] ?? '',
      ratingCommunication: _parseDouble(d['ratingCommunication']),
      ratingQuality: _parseDouble(d['ratingQuality']),
      ratingDescribed: _parseDouble(d['ratingDescribed']),
      publicReview: d['publicReview'] as String?,
      privateFeedback: d['privateFeedback'] as String?,
      overallRating: _parseDouble(d['overallRating']),
      buyerReview: d['buyerReview'] as Map<String, dynamic>?,
      sellerReview: d['sellerReview'] as Map<String, dynamic>?,
      hasReview: d['hasReview'] ?? false,
      isReviewPublic: d['isReviewPublic'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    // Sanitize: remove null or empty optional values to prevent Firestore issues
    final map = <String, dynamic>{
      'gigId': gigId,
      'gigTitle': gigTitle,
      'packageName': packageName,
      'price': price,
      'basePrice': basePrice > 0 ? basePrice : price,
      'discountAmount': discountAmount,
      'quantity': quantity,
      'deliveryDays': deliveryDays,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'authorId': authorId,
      'projectDetails': projectDetails,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'deliveryNote': deliveryNote,
      'deliveryLink': deliveryLink,
      'revisionNote': revisionNote,
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (startedAt != null) 'startedAt': Timestamp.fromDate(startedAt!),
      if (deliveredAt != null) 'deliveredAt': Timestamp.fromDate(deliveredAt!),
      if (ratingCommunication != null) 'ratingCommunication': ratingCommunication,
      if (ratingQuality != null) 'ratingQuality': ratingQuality,
      if (ratingDescribed != null) 'ratingDescribed': ratingDescribed,
      if (publicReview != null) 'publicReview': publicReview,
      if (privateFeedback != null) 'privateFeedback': privateFeedback,
      if (overallRating != null) 'overallRating': overallRating,
      if (buyerReview != null) 'buyerReview': buyerReview,
      if (sellerReview != null) 'sellerReview': sellerReview,
      'hasReview': hasReview,
      'isReviewPublic': isReviewPublic,
    };

    // Only add packageId if non-empty
    if (packageId.isNotEmpty) map['packageId'] = packageId;

    return map;
  }

  Color get statusColor {
    switch (status) {
      case 'pending_payment': return const Color(0xFFEF4444); // Red
      case 'requirements':  return const Color(0xFFF59E0B); // Amber
      case 'in_progress':   return const Color(0xFF3B82F6); // Blue
      case 'delivered':     return const Color(0xFF8B5CF6); // Purple
      case 'completed':     return const Color(0xFF1BCA75); // Green
      case 'cancelled':     return const Color(0xFFEF4444); // Red
      case 'cancel_requested_by_buyer': return const Color(0xFFF97316); // Orange
      case 'cancel_requested_by_freelancer': return const Color(0xFFF97316); // Orange
      case 'disputed':      return const Color(0xFFDC2626); // Dark Red
      // Legacy statuses
      case 'pending':       return const Color(0xFFF59E0B);
      default:              return const Color(0xFFF59E0B);
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending_payment': return 'Waiting for Payment';
      case 'requirements':  return 'Requirements';
      case 'in_progress':   return 'In Progress';
      case 'delivered':     return 'Delivered';
      case 'completed':     return 'Completed';
      case 'cancelled':     return 'Cancelled';
      case 'cancel_requested_by_buyer': return 'Cancel Requested (Buyer)';
      case 'cancel_requested_by_freelancer': return 'Cancel Requested (Seller)';
      case 'disputed':      return 'Disputed';
      case 'pending':       return 'Pending';
      default:              return status;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'pending_payment': return Icons.payment_outlined;
      case 'requirements':  return Icons.assignment_outlined;
      case 'in_progress':   return Icons.autorenew_rounded;
      case 'delivered':     return Icons.local_shipping_outlined;
      case 'completed':     return Icons.check_circle_outline;
      case 'cancelled':     return Icons.cancel_outlined;
      case 'cancel_requested_by_buyer': return Icons.help_outline;
      case 'cancel_requested_by_freelancer': return Icons.help_outline;
      case 'disputed':      return Icons.warning_amber_rounded;
      default:              return Icons.hourglass_empty;
    }
  }
}
