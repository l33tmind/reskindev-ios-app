import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final List<String> participants;
  final Map<String, dynamic> participantDetails;
  final String lastMessage;
  final DateTime? updatedAt;
  final Map<String, int> unreadCount;
  final Map<String, bool> typing;
  final String freelancerId;
  final String clientId;
  final String? orderId; // Null for inbox, holds ID for order workstream
  final List<String> archivedBy;

  ConversationModel({
    required this.id,
    required this.participants,
    required this.participantDetails,
    required this.lastMessage,
    this.updatedAt,
    required this.unreadCount,
    required this.typing,
    this.freelancerId = '',
    this.clientId = '',
    this.orderId,
    this.archivedBy = const [],
  });

  factory ConversationModel.fromMap(String id, Map<String, dynamic> data) {
    return ConversationModel(
      id: id,
      participants: List<String>.from(data['participants'] ?? []),
      participantDetails: Map<String, dynamic>.from(data['participantDetails'] ?? {}),
      lastMessage: data['lastMessage'] ?? '',
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
      typing: Map<String, bool>.from(data['typing'] ?? {}),
      freelancerId: data['freelancerId'] ?? (List<String>.from(data['participants'] ?? []).length > 1 ? List<String>.from(data['participants'] ?? [])[1] : ''),
      clientId: data['clientId'] ?? (List<String>.from(data['participants'] ?? []).isNotEmpty ? List<String>.from(data['participants'] ?? [])[0] : ''),
      orderId: data['orderId'],
      archivedBy: List<String>.from(data['archivedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'participants': participants,
      'participantDetails': participantDetails,
      'lastMessage': lastMessage,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'unreadCount': unreadCount,
      'typing': typing,
      'freelancerId': freelancerId,
      'clientId': clientId,
      'archivedBy': archivedBy,
    };
    if (orderId != null) map['orderId'] = orderId!;
    return map;
  }
}

class MessageModel {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final DateTime? createdAt;
  final String type; // "text", "system_notification", etc.
  final bool isSystem; // true for system cards
  final Map<String, dynamic>? metadata;
  
  // Specific fields for Rich UI
  final String? actionType;
  final String? orderId;
  final num? rating;
  final num? sellerRating;
  final String? comment;
  final String? sellerComment;
  final num? price;

  final num? offerPrice;
  final int? offerDays;
  final String? offerDescription;
  final String? imageUrl;
  final String? replyToId;
  final String? replyToText;
  final String? replyToSender;
  final String? gigTitle;

  MessageModel({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    this.createdAt,
    this.type = 'text',
    this.isSystem = false,
    this.metadata,
    this.actionType,
    this.orderId,
    this.rating,
    this.sellerRating,
    this.comment,
    this.sellerComment,
    this.price,
    this.offerPrice,
    this.offerDays,
    this.offerDescription,
    this.imageUrl,
    this.replyToId,
    this.replyToText,
    this.replyToSender,
    this.gigTitle,
  });

  factory MessageModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parsedDate;
    try {
      if (data['createdAt'] is Timestamp) {
        parsedDate = (data['createdAt'] as Timestamp).toDate();
      } else if (data['createdAt'] is int) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(data['createdAt']);
      } else if (data['createdAt'] is String) {
        parsedDate = DateTime.tryParse(data['createdAt']);
      }
    } catch (e) {
      print('Error parsing createdAt in MessageModel: $e');
    }

    return MessageModel(
      id: id,
      text: data['text']?.toString() ?? '',
      senderId: data['senderId']?.toString() ?? '',
      senderName: data['senderName']?.toString() ?? '',
      createdAt: parsedDate,
      type: data['type']?.toString() ?? 'text',
      isSystem: data['system'] ?? (data['senderId'] == 'system'),
      metadata: data['metadata'] != null ? Map<String, dynamic>.from(data['metadata']) : null,
      actionType: data['actionType']?.toString(),
      orderId: data['orderId']?.toString(),
      rating: data['rating'] != null ? num.tryParse(data['rating'].toString()) : null,
      sellerRating: data['sellerRating'] != null ? num.tryParse(data['sellerRating'].toString()) : null,
      comment: data['comment']?.toString(),
      sellerComment: data['sellerComment']?.toString(),
      price: data['price'] != null ? num.tryParse(data['price'].toString()) : null,
      offerPrice: data['offerPrice'] != null ? num.tryParse(data['offerPrice'].toString()) : null,
      offerDays: data['offerDays'] != null ? int.tryParse(data['offerDays'].toString()) : null,
      offerDescription: data['offerDescription']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
      replyToId: data['replyToId']?.toString(),
      replyToText: data['replyToText']?.toString(),
      replyToSender: data['replyToSender']?.toString(),
      gigTitle: data['gigTitle']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'type': type,
      'system': isSystem,
    };
    if (metadata != null) map['metadata'] = metadata!;
    if (actionType != null) map['actionType'] = actionType!;
    if (orderId != null) map['orderId'] = orderId!;
    if (rating != null) map['rating'] = rating!;
    if (sellerRating != null) map['sellerRating'] = sellerRating!;
    if (comment != null) map['comment'] = comment!;
    if (sellerComment != null) map['sellerComment'] = sellerComment!;
    if (price != null) map['price'] = price!;
    if (type == 'custom_offer' || type == 'offer') {
      if (offerPrice != null) map['offerPrice'] = offerPrice!;
      if (offerDays != null) map['offerDays'] = offerDays!;
      if (offerDescription != null) map['offerDescription'] = offerDescription!;
    }
    if (type == 'image' && imageUrl != null) {
      map['imageUrl'] = imageUrl!;
    }
    if (replyToId != null) map['replyToId'] = replyToId!;
    if (replyToText != null) map['replyToText'] = replyToText!;
    if (replyToSender != null) map['replyToSender'] = replyToSender!;
    if (gigTitle != null) map['gigTitle'] = gigTitle!;
    return map;
  }
}
