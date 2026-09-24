import 'dart:io';

void main() {
  final files = [
    File('lib/screens/favorites_screen.dart'),
    File('lib/screens/seller_profile_screen.dart'),
  ];
  
  for (var file in files) {
    var content = file.readAsStringSync();
    
    final oldCode = '''
                  return GestureDetector(
                    onTap: () => context.push('/gig/\${gig.id}', extra: gig),
                    child: GigCard(gig: gig),
                  );
''';
    final newCode = '''
                  return GigCard(
                    gig: gig,
                    onTap: () => context.push('/gig/\${gig.id}', extra: gig),
                  );
''';
    if (content.contains(oldCode)) {
      content = content.replaceFirst(oldCode, newCode);
    }
    
    // Check if there are other variants without the \ (due to Dart string parsing)
    final oldCode2 = "return GestureDetector(\n                    onTap: () => context.push('/gig/\${gig.id}', extra: gig),\n                    child: GigCard(gig: gig),\n                  );";
    final newCode2 = "return GigCard(\n                    gig: gig,\n                    onTap: () => context.push('/gig/\${gig.id}', extra: gig),\n                  );";
    if (content.contains(oldCode2)) {
      content = content.replaceFirst(oldCode2, newCode2);
    }
    
    // Also there might be a GestureDetector wrapper
    content = content.replaceAll('child: GigCard(gig: gig)', 'child: GigCard(gig: gig, onTap: () => context.push(\'/gig/\${gig.id}\', extra: gig))');
    
    file.writeAsStringSync(content);
  }
  
  // Wait, I will just make onTap optional in gig_card.dart. That is much safer!
  final gigCardFile = File('lib/widgets/gig_card.dart');
  var gigCardContent = gigCardFile.readAsStringSync();
  gigCardContent = gigCardContent.replaceFirst('final VoidCallback onTap;', 'final VoidCallback? onTap;');
  gigCardContent = gigCardContent.replaceFirst('required this.onTap', 'this.onTap');
  gigCardContent = gigCardContent.replaceFirst('onTap: widget.onTap,', 'onTap: widget.onTap ?? () {},');
  gigCardFile.writeAsStringSync(gigCardContent);

  print('Fixed GigCard args');
}
