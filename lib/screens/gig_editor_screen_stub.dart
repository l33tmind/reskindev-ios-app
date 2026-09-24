// Stub implementation for non-web platforms (Android, iOS, etc.)
import 'dart:typed_data';

class PickedImage {
  final Uint8List bytes;
  final String name;
  final String mimeType;
  PickedImage({required this.bytes, required this.name, required this.mimeType});
}

Future<PickedImage?> pickImageBytes() async {
  // Not available on non-web platforms
  return null;
}
