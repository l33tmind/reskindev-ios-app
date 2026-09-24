import 'dart:io';

void main() {
  final file = File('lib/screens/gig_detail_screen.dart');
  var content = file.readAsStringSync();

  // Add the Heart icon to AppBar
  final oldAppBar = '''
      appBar: AppBar(
        backgroundColor: context.themeSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: context.themeTextDark),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
''';
  final newAppBar = '''
      appBar: AppBar(
        backgroundColor: context.themeSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: context.themeTextDark),
        actions: [
          if (auth.user != null)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(auth.user!.uid).collection('favorites').doc(widget.gig.id).snapshots(),
              builder: (context, snapshot) {
                final isFav = snapshot.hasData && snapshot.data!.exists;
                return IconButton(
                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : context.themeTextDark),
                  onPressed: () async {
                    final ref = FirebaseFirestore.instance.collection('users').doc(auth.user!.uid).collection('favorites').doc(widget.gig.id);
                    if (isFav) {
                      await ref.delete();
                    } else {
                      await ref.set({'gigId': widget.gig.id, 'addedAt': FieldValue.serverTimestamp()});
                    }
                  },
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
''';
  if (content.contains(oldAppBar)) {
    content = content.replaceFirst(oldAppBar, newAppBar);
  } else {
    print("Could not find oldAppBar");
  }

  file.writeAsStringSync(content);
  print('Added Heart icon to gig_detail_screen.dart');
}
