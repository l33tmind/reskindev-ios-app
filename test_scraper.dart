import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

void main() async {
  final url = 'https://play.google.com/store/apps/details?id=com.reskindevdotcom.habito&hl=en';
  final proxyUrl = 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
  
  try {
    print('Fetching...');
    final response = await http.get(Uri.parse(proxyUrl));
    if (response.statusCode == 200) {
      final htmlStr = response.body;
      
      final document = parse(htmlStr);
      
      // Get title
      final titleElement = document.querySelector('title');
      String title = titleElement?.text ?? '';
      title = title.replaceAll(' - Apps on Google Play', '');
      print('Title: $title');
      
      // Get og:image (Icon)
      final ogImage = document.querySelector('meta[property="og:image"]');
      print('Icon URL: ${ogImage?.attributes['content']}');
      
      // Get Developer (harder, usually in an href containing 'developer?id=')
      final devElement = document.querySelector('a[href*="/store/apps/dev?id="] span');
      String dev = devElement?.text ?? '';
      print('Developer: $dev');
      
    } else {
      print('Failed: ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
