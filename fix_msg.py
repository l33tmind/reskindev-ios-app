with open('lib/models/chat_models.dart', 'r') as f:
    c = f.read()

old_fromMap = """  factory MessageModel.fromMap(String id, Map<String, dynamic> data) {
    return MessageModel(
      id: id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
      type: data['type'] ?? 'text',
      isSystem: data['system'] ?? (data['senderId'] == 'system'),
      metadata: data['metadata'] != null ? Map<String, dynamic>.from(data['metadata']) : null,
      actionType: data['actionType'],
      orderId: data['orderId'],
      rating: data['rating'],
      comment: data['comment'],
      price: data['price'],
      offerPrice: data['offerPrice'],
      offerDays: data['offerDays'],
      offerDescription: data['offerDescription'],
      imageUrl: data['imageUrl'],
      replyToId: data['replyToId'],
      replyToText: data['replyToText'],
      replyToSender: data['replyToSender'],
      gigTitle: data['gigTitle'],
    );
  }"""

new_fromMap = """  factory MessageModel.fromMap(String id, Map<String, dynamic> data) {
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
      rating: data['rating'] as num?,
      comment: data['comment']?.toString(),
      price: data['price'] as num?,
      offerPrice: data['offerPrice'] as num?,
      offerDays: data['offerDays'] as int?,
      offerDescription: data['offerDescription']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
      replyToId: data['replyToId']?.toString(),
      replyToText: data['replyToText']?.toString(),
      replyToSender: data['replyToSender']?.toString(),
      gigTitle: data['gigTitle']?.toString(),
    );
  }"""
c = c.replace(old_fromMap, new_fromMap)
with open('lib/models/chat_models.dart', 'w') as f:
    f.write(c)
