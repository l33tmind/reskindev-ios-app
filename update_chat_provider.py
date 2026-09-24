with open('lib/providers/chat_provider.dart', 'r') as f:
    content = f.read()

# Update getOrCreateConversation to save freelancerId and clientId
old_block = """      updatedAt: null, // Will be set by serverTimestamp on first message
      unreadCount: {currentUserId: 0, targetUserId: 0},
      typing: {currentUserId: false, targetUserId: false},
    );"""

new_block = """      updatedAt: null, // Will be set by serverTimestamp on first message
      unreadCount: {currentUserId: 0, targetUserId: 0},
      typing: {currentUserId: false, targetUserId: false},
      freelancerId: targetUserId,
      clientId: currentUserId,
    );"""

content = content.replace(old_block, new_block)

with open('lib/providers/chat_provider.dart', 'w') as f:
    f.write(content)
print("Updated chat_provider.dart")
