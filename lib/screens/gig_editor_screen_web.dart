// Web implementation using dart:html
import 'dart:html' as html;
import 'dart:typed_data';

class PickedImage {
  final Uint8List bytes;
  final String name;
  final String mimeType;
  PickedImage({required this.bytes, required this.name, required this.mimeType});
}

Future<PickedImage?> pickImageBytes() async {
  final input = html.FileUploadInputElement();
  input.accept = 'image/*';
  input.click();

  await input.onChange.first;
  if (input.files == null || input.files!.isEmpty) return null;

  final file = input.files!.first;
  final reader = html.FileReader();
  final loadEnd = reader.onLoadEnd.first;
  reader.readAsArrayBuffer(file);
  await loadEnd;

  final bytes = reader.result as Uint8List;
  return PickedImage(bytes: bytes, name: file.name, mimeType: file.type);
}
