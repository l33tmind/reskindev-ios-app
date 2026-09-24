import 'dart:io';

void main() {
  var gigCardFile = File('lib/widgets/gig_card.dart');
  var gigCardContent = gigCardFile.readAsStringSync();
  gigCardContent = gigCardContent.replaceAll(
    '\\\$' + String.fromCharCode(36) + '{startingPrice', 
    '\\\$' + '\${startingPrice'
  );
  gigCardFile.writeAsStringSync(gigCardContent);

  print('Fixed starting price');
}
