import re

with open('lib/models/chat_models.dart', 'r') as f:
    content = f.read()

# Add fields to ConversationModel
fields = """  final Map<String, bool> typing;
  final String freelancerId;
  final String clientId;"""

content = content.replace("  final Map<String, bool> typing;", fields)

constructor = """    required this.typing,
    this.freelancerId = '',
    this.clientId = '',"""

content = content.replace("    required this.typing,", constructor)

from_map = """      typing: Map<String, bool>.from(data['typing'] ?? {}),
      freelancerId: data['freelancerId'] ?? (List<String>.from(data['participants'] ?? []).length > 1 ? List<String>.from(data['participants'] ?? [])[1] : ''),
      clientId: data['clientId'] ?? (List<String>.from(data['participants'] ?? []).isNotEmpty ? List<String>.from(data['participants'] ?? [])[0] : ''),"""

content = content.replace("      typing: Map<String, bool>.from(data['typing'] ?? {}),", from_map)

to_map = """      'unreadCount': unreadCount,
      'typing': typing,
      'freelancerId': freelancerId,
      'clientId': clientId,"""

content = content.replace("      'unreadCount': unreadCount,\n      'typing': typing,", to_map)

with open('lib/models/chat_models.dart', 'w') as f:
    f.write(content)
print("Updated chat_models.dart")
