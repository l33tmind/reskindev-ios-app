import 'dart:io';

void main() {
  final file = File('lib/models/gig_model.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceFirst(
    '    this.authorName = \'\',',
    '    this.authorName = \'\',\n    this.reviewCount = 0,\n    this.averageRating = 0.0,'
  );
  
  file.writeAsStringSync(content);
}
