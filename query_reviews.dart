import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = "https://firestore.googleapis.com/v1/projects/reskindev-769d3/databases/(default)/documents/services?key=AIzaSyCUnsddGBcU-_ncIPcht3KfHPuvgl8cPEo";
  final res = await http.get(Uri.parse(url));
  final data = jsonDecode(res.body);
  final docs = data['documents'] as List;
  
  for (var doc in docs) {
    final name = doc['name'];
    final reviewsUrl = "https://firestore.googleapis.com/v1/$name/reviews?key=AIzaSyCUnsddGBcU-_ncIPcht3KfHPuvgl8cPEo";
    final revRes = await http.get(Uri.parse(reviewsUrl));
    if (revRes.statusCode == 200) {
      final revData = jsonDecode(revRes.body);
      if (revData['documents'] != null) {
        print("Found reviews in $name:");
        print(revData['documents']);
      }
    }
  }
}
