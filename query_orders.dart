import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = "https://firestore.googleapis.com/v1/projects/reskindev-769d3/databases/(default)/documents/orders?key=AIzaSyCUnsddGBcU-_ncIPcht3KfHPuvgl8cPEo";
  final res = await http.get(Uri.parse(url));
  if (res.statusCode == 200) {
    final data = jsonDecode(res.body);
    final docs = data['documents'] as List?;
    if (docs != null) {
      for (var doc in docs) {
        print(doc['name']);
        print(doc['fields']);
        print("---");
      }
    } else {
      print("No orders found.");
    }
  } else {
    print(res.body);
  }
}
