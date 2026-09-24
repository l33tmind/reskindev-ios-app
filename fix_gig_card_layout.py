import re

with open('lib/widgets/gig_card.dart', 'r') as f:
    content = f.read()

# Replace the build method of GigCard
# Look for: @override\n  Widget build(BuildContext context) { ... until the end.
start_idx = content.find("  @override\n  Widget build(BuildContext context) {")
if start_idx != -1:
    new_build = """  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = _getThumbnailUrl(gig);
    final startingPrice = gig.packages.isNotEmpty ? gig.packages.first.price : gig.basePrice;

    return GestureDetector(
      onTap: onTap ?? () => context.push('/gig/${gig.id}', extra: gig),
      child: Container(
        decoration: BoxDecoration(
          color: context.themeSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: context.isDarkMode ? Colors.transparent : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: context.themeBorder),
                        errorWidget: (context, url, error) => Container(color: context.themeBorder),
                      )
                    : Container(color: context.themeBorder),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gig.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: context.themeTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Starting at',
                    style: GoogleFonts.inter(fontSize: 11, color: context.themeTextLight),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\\$${startingPrice.toStringAsFixed(1)}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppTheme.primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward, size: 14, color: AppTheme.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}"""
    content = content[:start_idx] + new_build
    with open('lib/widgets/gig_card.dart', 'w') as f:
        f.write(content)
    print("Updated GigCard layout")
else:
    print("Could not find build method")
