import re

with open('lib/screens/gig_detail_screen.dart', 'r') as f:
    content = f.read()

old_fav = """                      if (FirebaseAuth.instance.currentUser != null)
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .collection('favorites')
                              .doc(gig.id)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final isFav = snapshot.hasData && snapshot.data!.exists;
                            return IconButton(
                              icon: Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFav ? Colors.red : context.themeTextDark),
                              onPressed: () async {
                                final ref = FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(FirebaseAuth.instance.currentUser!.uid)
                                    .collection('favorites')
                                    .doc(gig.id);
                                if (isFav) {
                                  await ref.delete();
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from Wishlist')));
                                } else {
                                  await ref.set({'gigId': gig.id, 'addedAt': FieldValue.serverTimestamp()});
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to Wishlist!')));
                                }
                              },
                            );
                          },
                        ),"""

new_fav = """                      if (FirebaseAuth.instance.currentUser != null)
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final userData = snapshot.hasData && snapshot.data!.exists ? snapshot.data!.data() as Map<String, dynamic> : {};
                            final savedGigs = List<String>.from(userData['savedGigs'] ?? []);
                            final isFav = savedGigs.contains(gig.id);
                            
                            return IconButton(
                              icon: Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFav ? Colors.red : context.themeTextDark),
                              onPressed: () async {
                                final ref = FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(FirebaseAuth.instance.currentUser!.uid);
                                if (isFav) {
                                  await ref.update({'savedGigs': FieldValue.arrayRemove([gig.id])});
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from Wishlist')));
                                } else {
                                  await ref.update({'savedGigs': FieldValue.arrayUnion([gig.id])});
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to Wishlist!')));
                                }
                              },
                            );
                          },
                        ),"""

if old_fav in content:
    content = content.replace(old_fav, new_fav)
    with open('lib/screens/gig_detail_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed gig_detail_screen favorites")
else:
    print("Could not find old favorites logic")
