import 'dart:convert';
import 'dart:io';

void main() async {
  final url = Uri.parse('https://firestore.googleapis.com/v1/projects/reskindev-769d3/databases/(default)/documents/services');
  final request = await HttpClient().getUrl(url);
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  final data = jsonDecode(responseBody);
  
  if (data['documents'] != null) {
    for (var doc in data['documents']) {
      final fields = doc['fields'];
      final title = fields['title']?['stringValue'] ?? '';
      if (title.toLowerCase().contains('vpn app')) {
        print("TITLE: $title");
        print("IMAGE_URL: ${fields['imageUrl']}");
        print("YOUTUBE_URL: ${fields['youtubeUrl']}");
        print("GALLERY: ${fields['galleryImages']}");
        print("---");
      }
    }
  }
}
