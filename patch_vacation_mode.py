import re

with open('lib/screens/profile_screen.dart', 'r') as f:
    c = f.read()

# Add vacation mode switch under Seller Dashboard
old_menu = """                onTap: () => context.push('/seller'),
              ),
              const _MenuDivider(),
              _MenuTile(
                icon: Icons.bolt_rounded,
                iconColor: Colors.amber,
                title: 'Quick Replies',
                subtitle: 'Manage saved messages for chat',
                onTap: () => context.push('/quick-replies'),
              ),
            ],
            const _MenuDivider(),"""

new_menu = """                onTap: () => context.push('/seller'),
              ),
              const _MenuDivider(),
              _MenuTile(
                icon: Icons.bolt_rounded,
                iconColor: Colors.amber,
                title: 'Quick Replies',
                subtitle: 'Manage saved messages for chat',
                onTap: () => context.push('/quick-replies'),
              ),
              const _MenuDivider(),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(auth.user?.uid).snapshots(),
                builder: (context, snapshot) {
                  final isVacation = (snapshot.data?.data() as Map<String, dynamic>?)?['vacationMode'] ?? false;
                  return SwitchListTile(
                    title: Text('Vacation Mode', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: context.themeTextDark)),
                    subtitle: Text('Temporarily hide your gigs', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
                    value: isVacation,
                    activeColor: AppTheme.primary,
                    secondary: Icon(Icons.beach_access_rounded, color: isVacation ? AppTheme.primary : context.themeTextLight),
                    onChanged: (val) async {
                      if (auth.user == null) return;
                      // Update user doc
                      await FirebaseFirestore.instance.collection('users').doc(auth.user!.uid).set({'vacationMode': val}, SetOptions(merge: true));
                      
                      // Update all their gigs
                      final snap = await FirebaseFirestore.instance.collection('services').where('authorId', isEqualTo: auth.user!.uid).get();
                      final batch = FirebaseFirestore.instance.batch();
                      for (var doc in snap.docs) {
                        batch.update(doc.reference, {'isVacation': val});
                      }
                      await batch.commit();
                    },
                  );
                },
              ),
            ],
            const _MenuDivider(),"""

c = c.replace(old_menu, new_menu)

with open('lib/screens/profile_screen.dart', 'w') as f:
    f.write(c)

