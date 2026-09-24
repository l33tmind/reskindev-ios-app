import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = "https://firestore.googleapis.com/v1/projects/reskindev-769d3/databases/(default)/documents/services?key=AIzaSyCUnsddGBcU-_ncIPcht3KfHPuvgl8cPEo";
  final res = await http.get(Uri.parse(url));
  final data = jsonDecode(res.body);
  final docs = data['documents'] as List;
  for (var doc in docs) {
    final fields = doc['fields'];
    if (fields['rating'] != null || fields['averageRating'] != null) {
      print("Gig ${doc['name']} has rating: ${fields['rating'] ?? fields['averageRating']}");
    }
  }
  print("Done checking ratings.");
}
