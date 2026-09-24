import re

with open('lib/models/chat_models.dart', 'r') as f:
    content = f.read()

old_fields = """  final String? replyToId;
  final String? replyToText;
  final String? replyToSender;

  MessageModel({"""

new_fields = """  final String? replyToId;
  final String? replyToText;
  final String? replyToSender;
  final String? actionType;
  final String? gigTitle;
  final String? orderId;

  MessageModel({"""
content = content.replace(old_fields, new_fields)

old_constructor = """    this.replyToId,
    this.replyToText,
    this.replyToSender,
  });"""

new_constructor = """    this.replyToId,
    this.replyToText,
    this.replyToSender,
    this.actionType,
    this.gigTitle,
    this.orderId,
  });"""
content = content.replace(old_constructor, new_constructor)

old_factory = """      replyToId: data['replyToId'],
      replyToText: data['replyToText'],
      replyToSender: data['replyToSender'],
    );
  }"""

new_factory = """      replyToId: data['replyToId'],
      replyToText: data['replyToText'],
      replyToSender: data['replyToSender'],
      actionType: data['actionType'],
      gigTitle: data['gigTitle'],
      orderId: data['orderId'],
    );
  }"""
content = content.replace(old_factory, new_factory)

old_tomap = """    if (replyToSender != null) map['replyToSender'] = replyToSender!;
    return map;
  }"""

new_tomap = """    if (replyToSender != null) map['replyToSender'] = replyToSender!;
    if (actionType != null) map['actionType'] = actionType!;
    if (gigTitle != null) map['gigTitle'] = gigTitle!;
    if (orderId != null) map['orderId'] = orderId!;
    return map;
  }"""
content = content.replace(old_tomap, new_tomap)

with open('lib/models/chat_models.dart', 'w') as f:
    f.write(content)

print("Updated MessageModel")
