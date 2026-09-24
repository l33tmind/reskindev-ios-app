import 'dart:io';

void main() {
  final file = File('lib/screens/gig_editor_screen.dart');
  final lines = file.readAsLinesSync();
  
  // Find upload image button
  int uploadStartIdx = -1;
  int uploadEndIdx = -1;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('ElevatedButton.icon(') && lines[i+1].contains('onPressed: _isUploading ? null : () async {')) {
      uploadStartIdx = i - 1; // get the SizedBox
      for (int j = i; j < lines.length; j++) {
        if (lines[j].contains('),') && lines[j-1].contains('),')) {
          // Find the end of the button
          if (lines[j].trim() == '),') {
            uploadEndIdx = j;
            break;
          }
        }
      }
      break;
    }
  }

  // Find whatsapp field
  int whatsappIdx = -1;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains("_buildTextField(_whatsappCtrl, 'WhatsApp Number")) {
      whatsappIdx = i;
      break;
    }
  }

  // Delete from bottom to top so indices don't shift
  if (whatsappIdx != -1) {
    print('Removing whatsapp at line \$whatsappIdx');
    // also remove the sizedbox before it
    lines.removeAt(whatsappIdx);
    lines.removeAt(whatsappIdx - 1); 
  }

  if (uploadStartIdx != -1 && uploadEndIdx != -1) {
    print('Removing upload button from \$uploadStartIdx to \$uploadEndIdx');
    lines.removeRange(uploadStartIdx, uploadEndIdx + 1);
  }
  
  file.writeAsStringSync(lines.join('\n'));
}
