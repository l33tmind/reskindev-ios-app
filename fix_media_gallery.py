import re

with open('lib/screens/gig_detail_screen.dart', 'r') as f:
    content = f.read()

# Replace the stack in _buildMediaGallery
old_stack = """                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'gig_image_${gig.id}',
                        child: ImageFiltered(
                          imageFilter: isEffectivelyLocked
                              ? ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5)
                              : ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                          child: Image.network(
                            isYT ? maxResThumbUrl : currentMedia,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image, size: 64, color: Colors.grey)),
                          ),
                        ),
                      ),
                     ],
                  ),"""

new_stack = """                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'gig_image_${gig.id}',
                        child: isEffectivelyLocked
                            ? ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                                child: Image.network(
                                  isYT ? maxResThumbUrl : currentMedia,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey)),
                                ),
                              )
                            : Image.network(
                                isYT ? maxResThumbUrl : currentMedia,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey)),
                              ),
                      ),
                     ],
                  ),"""

if old_stack in content:
    content = content.replace(old_stack, new_stack)
    with open('lib/screens/gig_detail_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed ImageFiltered zero-blur bug in GigDetailScreen")
else:
    print("Could not find old_stack in GigDetailScreen")
