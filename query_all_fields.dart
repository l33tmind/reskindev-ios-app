import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = "https://firestore.googleapis.com/v1/projects/reskindev-769d3/databases/(default)/documents/services?key=AIzaSyCUnsddGBcU-_ncIPcht3KfHPuvgl8cPEo";
  final res = await http.get(Uri.parse(url));
  if (res.statusCode == 200) {
    final data = jsonDecode(res.body);
    final docs = data['documents'] as List;
    for (var doc in docs) {
      final fields = doc['fields'] as Map<String, dynamic>;
      final keys = fields.keys.where((k) => k.toLowerCase().contains('rating') || k.toLowerCase().contains('review')).toList();
      if (keys.isNotEmpty) {
        print(doc['name']);
        for (var k in keys) {
          print("$k: ${fields[k]}");
        }
      }
    }
  }
}
