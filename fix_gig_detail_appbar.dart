import 'dart:io';

void main() {
  final file = File('lib/screens/gig_detail_screen.dart');
  var content = file.readAsStringSync();
  
  final oldAppBar = '''
                  : AppBar(
                    backgroundColor: context.themeSurface,
                    elevation: 0,
                    iconTheme: IconThemeData(color: context.themeTextDark),
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back, color: context.themeTextDark),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                    ),

                  ),
''';
  final newAppBar = '''
                  : AppBar(
                    backgroundColor: context.themeSurface,
                    elevation: 0,
                    iconTheme: IconThemeData(color: context.themeTextDark),
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back, color: context.themeTextDark),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                    ),
                    actions: [
                      if (FirebaseAuth.instance.currentUser != null)
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
                        ),
                      IconButton(
                        icon: const Icon(Icons.share_rounded),
                        onPressed: () {
                          // Placeholder for share
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share functionality coming soon')));
                        },
                      ),
                    ],
                  ),
''';
  if (content.contains(oldAppBar)) {
    content = content.replaceFirst(oldAppBar, newAppBar);
    print("Replaced AppBar");
  } else {
    print("Could not find AppBar");
  }

  file.writeAsStringSync(content);
}
