import re
import os

# fix seller profile screen banner
with open('lib/screens/seller_profile_screen.dart', 'r') as f:
    content = f.read()

content = content.replace(
    "CachedNetworkImage(imageUrl: user.bannerUrl, fit: BoxFit.cover)",
    "Image.network(user.bannerUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey.shade200))"
)
content = content.replace(
    "backgroundImage: user.photoUrl.isNotEmpty ? CachedNetworkImageProvider(user.photoUrl) : null",
    "backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null"
)

with open('lib/screens/seller_profile_screen.dart', 'w') as f:
    f.write(content)

# fix chat bubble
with open('lib/widgets/chat_bubble.dart', 'r') as f:
    content = f.read()

chat_old = """              CachedNetworkImage(
                imageUrl: message.imageUrl!,
                width: 200,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(width: 200, height: 150, color: Colors.grey.shade200),
                errorWidget: (context, url, error) => Container(width: 200, height: 150, color: Colors.grey.shade200, child: const Icon(Icons.error)),
              )"""
chat_new = """              Image.network(
                message.imageUrl!,
                width: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(width: 200, height: 150, color: Colors.grey.shade200, child: const Icon(Icons.error)),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(width: 200, height: 150, color: Colors.grey.shade200);
                },
              )"""

if chat_old in content:
    content = content.replace(chat_old, chat_new)
    with open('lib/widgets/chat_bubble.dart', 'w') as f:
        f.write(content)

print("Fixed other CachedNetworkImage instances")
