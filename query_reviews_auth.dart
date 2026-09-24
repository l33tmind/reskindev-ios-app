import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final name = "projects/reskindev-769d3/databases/(default)/documents/services/cCrWk5uidjbnGGZ9ptEN";
  final reviewsUrl = "https://firestore.googleapis.com/v1/$name/reviews?key=AIzaSyCUnsddGBcU-_ncIPcht3KfHPuvgl8cPEo";
  final revRes = await http.get(Uri.parse(reviewsUrl));
  print(revRes.statusCode);
  print(revRes.body);
}
