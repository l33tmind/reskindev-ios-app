import re

with open('lib/screens/gig_detail_screen.dart', 'r') as f:
    content = f.read()

old_block = """                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance.collection('users').where('email', isEqualTo: 'mdrobiussany1225@gmail.com').limit(1).get(),
                  builder: (context, snapshot) {
                    String name = 'Reskindev Admin';
                    String photoUrl = 'https://ui-avatars.com/api/?name=Reskindev+Admin&background=0D8ABC&color=fff';
                    
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                      name = data['name'] ?? data['displayName'] ?? name;
                      if (name.isEmpty) name = 'Reskindev Admin';
                      
                      final pUrl = data['photoUrl'] as String?;
                      if (pUrl != null && pUrl.isNotEmpty) {
                        photoUrl = pUrl;
                      } else {
                        photoUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0D8ABC&color=fff';
                      }
                    }"""

new_block = """                FutureBuilder<DocumentSnapshot>(
                  future: gig.authorId.isNotEmpty ? FirebaseFirestore.instance.collection('users').doc(gig.authorId).get() : Future.value(null),
                  builder: (context, snapshot) {
                    String name = gig.authorName.isNotEmpty ? gig.authorName : 'Verified Seller';
                    String photoUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0D8ABC&color=fff';
                    
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      final pName = data['name'] ?? data['displayName'];
                      if (pName != null && pName.toString().isNotEmpty) {
                        name = pName.toString();
                      }
                      
                      final pUrl = data['photoUrl'] as String?;
                      if (pUrl != null && pUrl.isNotEmpty) {
                        photoUrl = pUrl;
                      } else {
                        photoUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0D8ABC&color=fff';
                      }
                    }"""

if old_block in content:
    content = content.replace(old_block, new_block)
    with open('lib/screens/gig_detail_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed hardcoded author logic!")
else:
    print("Could not find hardcoded author logic")
