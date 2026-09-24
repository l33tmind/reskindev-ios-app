import re

with open('lib/screens/gig_detail_screen.dart', 'r') as f:
    content = f.read()

old_share = """                      IconButton(
                        icon: const Icon(Icons.share_rounded),
                        onPressed: () {
                          final shareUrl = 'https://reskindev.com/gig/${gig.id}';
                          Share.share(
                            '🌟 Check out this service: ${gig.title}\\n\\n$shareUrl',
                            subject: gig.title,
                          );
                        },
                      ),"""

new_share = """                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.share_rounded),
                          onPressed: () async {
                            final shareUrl = 'https://reskindev.com/gig/${gig.id}';
                            final box = ctx.findRenderObject() as RenderBox?;
                            try {
                              await Share.share(
                                '🌟 Check out this service: ${gig.title}\\n\\n$shareUrl',
                                subject: gig.title,
                                sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
                              );
                            } catch (e) {
                              debugPrint('Share error: $e');
                            }
                          },
                        ),
                      ),"""

if old_share in content:
    content = content.replace(old_share, new_share)
    with open('lib/screens/gig_detail_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed GigDetailScreen Share")
else:
    print("Could not find Share button in GigDetailScreen")
