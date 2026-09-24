import 'dart:io';

void main() {
  final file = File('lib/screens/seller_dashboard_screen.dart');
  var content = file.readAsStringSync();

  final oldGigCard = '''
  Widget _buildGigCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final imageUrl = data['imageUrl'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final status = data['status'] as String? ?? 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.themeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(imageUrl, height: 150, width: double.infinity, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: context.themeTextDark))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: status == 'active' || status == 'published' ? Colors.green : Colors.orange, borderRadius: BorderRadius.circular(8)),
                      child: Text(status.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Need to pass GigModel
                          final gig = GigModel.fromFirestore(doc);
                          context.push('/seller/edit-gig', extra: gig);
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(context, doc.id),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
''';

  final newGigCard = '''
  Widget _buildGigCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final imageUrl = data['imageUrl'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final status = data['status'] as String? ?? 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: context.themeBorder.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  Image.network(imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover),
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'active' || status == 'published' ? const Color(0xFF10B981) : Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(status.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'active' || status == 'published' ? const Color(0xFF10B981).withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(status.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: status == 'active' || status == 'published' ? const Color(0xFF10B981) : Colors.orange)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  title,
                  style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: context.themeTextDark, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final gig = GigModel.fromFirestore(doc);
                          context.push('/seller/edit-gig', extra: gig);
                        },
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Edit Gig'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                          foregroundColor: AppTheme.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => _confirmDelete(context, doc.id),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
''';

  content = content.replaceAll(oldGigCard, newGigCard);
  file.writeAsStringSync(content);
}
