import 'dart:io';

void main() {
  final file = File('lib/screens/gig_editor_screen.dart');
  final lines = file.readAsLinesSync();
  
  int start = -1;
  int end = -1;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('Future<String?> _uploadImageToHosting() async {')) {
      start = i - 1; // get the bool _isUploading
      for (int j = i; j < lines.length; j++) {
        if (lines[j].trim() == '}') {
          if (lines[j-1].contains('setState(() => _isUploading = false);')) {
            end = j;
            break;
          }
        }
      }
      break;
    }
  }

  if (start != -1 && end != -1) {
    print('Removing upload func from \$start to \$end');
    lines.removeRange(start, end + 1);
    file.writeAsStringSync(lines.join('\n'));
  }
}
