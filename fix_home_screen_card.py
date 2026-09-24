import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

old_block = """              AspectRatio(
                aspectRatio: 16 / 9,
                child: thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: context.themeSurface),
                        errorWidget: (context, url, error) => Container(color: context.themeSurface, child: const Icon(Icons.image, color: Colors.grey)),
                      )
                    : Container(
                        color: context.themeSurface,
                        child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                      ),
              ),"""

new_block = """              AspectRatio(
                aspectRatio: 16 / 9,
                child: thumbnailUrl.isNotEmpty
                    ? Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: context.themeSurface,
                          child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(color: context.themeSurface);
                        },
                      )
                    : Container(
                        color: context.themeSurface,
                        child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                      ),
              ),"""

if old_block in content:
    content = content.replace(old_block, new_block)
    with open('lib/screens/home_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed _WebGigCard Image")
else:
    print("Could not find block in _WebGigCard")
