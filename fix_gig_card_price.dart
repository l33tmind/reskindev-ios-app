import 'dart:io';

void main() {
  var file = File('lib/widgets/gig_card.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll("'\\$\\$\\{startingPrice", "'\\$\\${startingPrice");
  file.writeAsStringSync(content);
}
