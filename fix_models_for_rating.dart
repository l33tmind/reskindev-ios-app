import 'dart:io';

void main() {
  // --- 1. Update OrderModel ---
  final orderFile = File('lib/models/order_model.dart');
  var orderContent = orderFile.readAsStringSync();
  
  if (!orderContent.contains('double? ratingCommunication;')) {
    orderContent = orderContent.replaceFirst(
      '  final String deliveryNote;',
      '''  final String deliveryNote;
  
  // Rating & Review
  final double? ratingCommunication;
  final double? ratingQuality;
  final double? ratingDescribed;
  final String? publicReview;
  final String? privateFeedback;
  final double? overallRating;
'''
    );

    orderContent = orderContent.replaceFirst(
      '    this.deliveryNote = \'\',',
      '''    this.deliveryNote = \'\',
    this.ratingCommunication,
    this.ratingQuality,
    this.ratingDescribed,
    this.publicReview,
    this.privateFeedback,
    this.overallRating,'''
    );

    orderContent = orderContent.replaceFirst(
      '      deliveryNote: d[\'deliveryNote\'] ?? \'\',',
      '''      deliveryNote: d['deliveryNote'] ?? '',
      ratingCommunication: (d['ratingCommunication'] as num?)?.toDouble(),
      ratingQuality: (d['ratingQuality'] as num?)?.toDouble(),
      ratingDescribed: (d['ratingDescribed'] as num?)?.toDouble(),
      publicReview: d['publicReview'] as String?,
      privateFeedback: d['privateFeedback'] as String?,
      overallRating: (d['overallRating'] as num?)?.toDouble(),'''
    );

    orderContent = orderContent.replaceFirst(
      '      if (completedAt != null) \'completedAt\': Timestamp.fromDate(completedAt!),',
      '''      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (ratingCommunication != null) 'ratingCommunication': ratingCommunication,
      if (ratingQuality != null) 'ratingQuality': ratingQuality,
      if (ratingDescribed != null) 'ratingDescribed': ratingDescribed,
      if (publicReview != null) 'publicReview': publicReview,
      if (privateFeedback != null) 'privateFeedback': privateFeedback,
      if (overallRating != null) 'overallRating': overallRating,'''
    );
    orderFile.writeAsStringSync(orderContent);
  }

  // --- 2. Update GigModel ---
  final gigFile = File('lib/models/gig_model.dart');
  var gigContent = gigFile.readAsStringSync();
  
  if (!gigContent.contains('int reviewCount;')) {
    gigContent = gigContent.replaceFirst(
      '  final String authorName;',
      '''  final String authorName;
      
  // Ratings
  final int reviewCount;
  final double averageRating;
'''
    );

    gigContent = gigContent.replaceFirst(
      '    required this.authorName,',
      '''    required this.authorName,
    this.reviewCount = 0,
    this.averageRating = 0.0,'''
    );

    gigContent = gigContent.replaceFirst(
      '      authorName: d[\'authorName\'] ?? \'\',',
      '''      authorName: d['authorName'] ?? '',
      reviewCount: (d['reviewCount'] as num?)?.toInt() ?? 0,
      averageRating: (d['averageRating'] as num?)?.toDouble() ?? 0.0,'''
    );

    gigContent = gigContent.replaceFirst(
      '      \'authorName\': authorName,',
      '''      'authorName': authorName,
      'reviewCount': reviewCount,
      'averageRating': averageRating,'''
    );
    gigFile.writeAsStringSync(gigContent);
  }
  
  print('Updated Models');
}
