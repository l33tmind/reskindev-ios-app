import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = "https://firestore.googleapis.com/v1/projects/reskindev-769d3/databases/(default)/documents/services?key=AIzaSyCUnsddGBcU-_ncIPcht3KfHPuvgl8cPEo";
  final res = await http.get(Uri.parse(url));
  final data = jsonDecode(res.body);
  final docs = data['documents'] as List;
  int ratedCount = 0;
  for (var doc in docs) {
    final fields = doc['fields'];
    if (fields['rating'] != null || fields['averageRating'] != null) {
      print("Gig ${fields['title']?['stringValue']} has rating: ${fields['averageRating']?['doubleValue'] ?? fields['averageRating']?['integerValue'] ?? fields['rating']?['doubleValue'] ?? fields['rating']?['integerValue']}");
      ratedCount++;
    }
  }
  print("Total gigs with ratings: $ratedCount");
}
