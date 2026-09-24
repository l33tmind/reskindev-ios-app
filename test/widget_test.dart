import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_platform/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp(initialThemeMode: ThemeMode.system));
  });
}
