with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

block_to_find = """                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFFB33E), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            widget.gig.averageRating > 0 ? widget.gig.averageRating.toStringAsFixed(1) : 'New',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFFB33E)),
                          ),
                          if (widget.gig.reviewCount > 0)
                            Text(
                              ' (${widget.gig.reviewCount})',
                              style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight),
                            ),
                        ],
                      ),"""

block_to_replace = """                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFFB33E), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            widget.gig.averageRating > 0 ? widget.gig.averageRating.toStringAsFixed(1) : 'New',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFFB33E)),
                          ),
                          if (widget.gig.reviewCount > 0)
                            Text(
                              ' (${widget.gig.reviewCount})',
                              style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight),
                            ),
                        ],
                      ),
                      const Spacer(),"""

if block_to_find in content:
    content = content.replace(block_to_find, block_to_replace)
    with open('lib/screens/home_screen.dart', 'w') as f:
        f.write(content)
    print("Updated home_screen.dart")
else:
    print("Could not find block in home_screen.dart")
