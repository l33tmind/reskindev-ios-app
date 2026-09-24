import 'dart:io';

void main() {
  final file = File('lib/screens/gig_editor_screen.dart');
  var content = file.readAsStringSync();
  
  final oldSaveSuccess = '''
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service saved successfully!'), backgroundColor: AppTheme.primary),
      );
      
      // Request review if it's a new gig creation
      if (widget.gig == null) {
        try {
          final InAppReview inAppReview = InAppReview.instance;
          if (await inAppReview.isAvailable()) {
            await inAppReview.requestReview();
          }
        } catch (e) {
          debugPrint('InAppReview error: \$e');
        }
      }
''';

  final newSaveSuccess = '''
      if (!mounted) return;
      
      if (widget.gig == null) {
        // Show smooth success + rating popup
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 64),
                  const SizedBox(height: 16),
                  Text('Gig Created!', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 8),
                  Text('Your service is now live. If you enjoy using our app, please take a moment to rate us!', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700], height: 1.4)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx); // Close dialog
                        Navigator.pop(context); // Close editor
                        try {
                          final InAppReview inAppReview = InAppReview.instance;
                          if (await inAppReview.isAvailable()) {
                            await inAppReview.requestReview();
                          }
                        } catch (e) {
                           debugPrint('Rating error: \$e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Rate App', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx); // Close dialog
                      Navigator.pop(context); // Close editor
                    },
                    child: Text('Maybe Later', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                  )
                ],
              ),
            ),
          ),
        );
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service updated successfully!'), backgroundColor: AppTheme.primary),
        );
      }
''';

  if (content.contains("if (widget.gig == null) {\n        try {\n          final InAppReview inAppReview = InAppReview.instance;")) {
      content = content.replaceAll(oldSaveSuccess, newSaveSuccess);
      file.writeAsStringSync(content);
      print('Replaced successfully!');
  } else {
      print('Could not find the exact block to replace.');
  }
}
