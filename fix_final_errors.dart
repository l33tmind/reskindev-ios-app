import 'dart:io';

void main() {
  // 1. Fix home_screen.dart (append missing classes)
  var homeFile = File('lib/screens/home_screen.dart');
  var homeContent = homeFile.readAsStringSync();
  homeContent += '''

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.themeCard,
      highlightColor: context.themeSurface,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _EmptyGigs extends StatelessWidget {
  const _EmptyGigs();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: context.themeTextLight),
            const SizedBox(height: 16),
            Text('No gigs found', style: GoogleFonts.outfit(fontSize: 20, color: context.themeTextDark)),
          ],
        ),
      ),
    );
  }
}

class _GigPlaceholder extends StatelessWidget {
  final GigModel gig;
  const _GigPlaceholder({required this.gig});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.themeSurface,
      child: Center(
        child: Icon(Icons.image, color: context.themeTextLight),
      ),
    );
  }
}
''';
  homeFile.writeAsStringSync(homeContent);

  // 2. Fix seller_dashboard_screen.dart (missing import)
  var sellerFile = File('lib/screens/seller_dashboard_screen.dart');
  var sellerContent = sellerFile.readAsStringSync();
  if (!sellerContent.contains('notification_service.dart')) {
    sellerContent = sellerContent.replaceFirst(
      "import '../theme.dart';",
      "import '../theme.dart';\nimport '../services/notification_service.dart';"
    );
    sellerFile.writeAsStringSync(sellerContent);
  }
  
  print("Fixed missing classes and imports");
}
