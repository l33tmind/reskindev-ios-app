import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:online_platform/models/gig_model.dart';
import 'package:online_platform/widgets/gig_cover.dart';
import 'package:online_platform/widgets/gig_description.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('inline "•" bullets become one ✓ row each, with the lead-in as a heading', (tester) async {
    const html = '<p>Are you looking for an app?</p>'
        '<p>My services include: • Spatial UI/UX • SwiftUI and RealityKit • Testing</p>'
        '<p>Let us build it!</p>';
    await tester.pumpWidget(_wrap(const GigDescription(html: html)));
    await tester.pump();

    expect(find.textContaining('My services include:'), findsOneWidget);
    expect(find.textContaining('Spatial UI/UX'), findsOneWidget);
    expect(find.textContaining('SwiftUI and RealityKit'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
    // Short enough to show whole: no "Read more"
    expect(find.text('Read more'), findsNothing);
  });

  testWidgets('long descriptions fold, open in place and fold again', (tester) async {
    final html = List.generate(8, (i) => '<p>Paragraph $i ${'with plenty of words to read ' * 4}</p>').join();
    await tester.pumpWidget(_wrap(GigDescription(html: html)));
    await tester.pump();

    expect(find.text('Read more'), findsOneWidget);
    expect(find.textContaining('Paragraph 7'), findsNothing);

    await tester.tap(find.text('Read more'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paragraph 7'), findsOneWidget);
    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('<li> items and "-" lines are list rows; plain text keeps its line breaks', (tester) async {
    await tester.pumpWidget(_wrap(const GigDescription(html: '<ul><li>One</li><li>Two</li></ul>')));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));

    await tester.pumpWidget(_wrap(const GigDescription(html: 'Hello there\n- First\n- Second')));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    expect(find.textContaining('Hello there'), findsOneWidget);
  });

  testWidgets('a gig without a picture gets a cover with its title and a category icon', (tester) async {
    final gig = GigModel(id: 'abc', title: 'I will edit your video', description: '', packages: const [], category: 'Video Editing');
    await tester.pumpWidget(MaterialApp(home: SizedBox(width: 360, height: 200, child: GigCover(gig: gig))));
    await tester.pump();
    expect(find.text('I will edit your video'), findsOneWidget);
    expect(find.byIcon(Icons.movie_creation_rounded), findsWidgets);

    // Small card: icon only
    await tester.pumpWidget(MaterialApp(home: SizedBox(width: 150, height: 84, child: GigCover(gig: gig, showTitle: false))));
    await tester.pump();
    expect(find.text('I will edit your video'), findsNothing);
  });
}
