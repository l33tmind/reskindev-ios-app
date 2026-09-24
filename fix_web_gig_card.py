with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

bad_heart = "Icon(Icons.favorite_border_rounded, size: 16, color: context.themeTextLight),"

good_heart = """Builder(
                                builder: (context) {
                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user == null) {
                                    return GestureDetector(
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please login to add to wishlist')),
                                        );
                                        context.push('/login');
                                      },
                                      child: Icon(Icons.favorite_border_rounded, size: 16, color: context.themeTextLight),
                                    );
                                  }
                                  
                                  final favRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('favorites').doc(widget.gig.id);
                                  
                                  return StreamBuilder<DocumentSnapshot>(
                                    stream: favRef.snapshots(),
                                    builder: (context, snapshot) {
                                      final isFav = snapshot.hasData && snapshot.data!.exists;
                                      
                                      return GestureDetector(
                                        onTap: () async {
                                          if (isFav) {
                                            await favRef.delete();
                                          } else {
                                            await favRef.set({
                                              'gigId': widget.gig.id,
                                              'addedAt': FieldValue.serverTimestamp(),
                                            });
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Added to wishlist'), duration: Duration(seconds: 1)),
                                              );
                                            }
                                          }
                                        },
                                        child: Icon(
                                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                                          size: 16, 
                                          color: isFav ? Colors.red : context.themeTextLight,
                                        ),
                                      );
                                    },
                                  );
                                }
                              ),"""

if bad_heart in content:
    content = content.replace(bad_heart, good_heart)
    with open('lib/screens/home_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed web GigCard heart icon")
else:
    print("Could not find heart icon in web GigCard")
