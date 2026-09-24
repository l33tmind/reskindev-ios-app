with open('lib/widgets/gig_card.dart', 'r') as f:
    content = f.read()

start_idx = content.find('// Title')
if start_idx != -1:
    replacement = """// Title
                    Text(
                      gig.title,
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: context.themeTextDark, height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const Spacer(),
                    
                    Divider(height: 1, color: context.themeBorder.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    
                    // Footer (Rating, Heart, Price)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Rating + Heart
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFFB33E), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              gig.averageRating > 0 ? gig.averageRating.toStringAsFixed(1) : 'New',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFFB33E)),
                            ),
                            if (gig.reviewCount > 0)
                              Text(
                                ' (${gig.reviewCount})',
                                style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight),
                              ),
                            const SizedBox(width: 12),
                            Icon(Icons.favorite_border_rounded, size: 16, color: context.themeTextLight),
                          ],
                        ),
                        
                        // Right: Price
                        Row(
                          children: [
                            Text(
                              'From ',
                              style: GoogleFonts.inter(fontSize: 10, color: context.themeTextLight, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '\\$${startingPrice.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: context.themeTextDark),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}"""
    content = content[:start_idx] + replacement
    with open('lib/widgets/gig_card.dart', 'w') as f:
        f.write(content)
    print("Updated gig_card.dart")
else:
    print("Could not find start idx")
