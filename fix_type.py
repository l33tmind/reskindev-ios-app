import re

with open('lib/screens/gig_detail_screen.dart', 'r') as f:
    content = f.read()

content = content.replace("FutureBuilder<DocumentSnapshot>(", "FutureBuilder<DocumentSnapshot?>(", 1)
content = content.replace("gig.authorId.isNotEmpty ? FirebaseFirestore.instance.collection('users').doc(gig.authorId).get() : Future.value(null)", "gig.authorId.isNotEmpty ? FirebaseFirestore.instance.collection('users').doc(gig.authorId).get() : Future.value(null)")

with open('lib/screens/gig_detail_screen.dart', 'w') as f:
    f.write(content)
