import re

with open('lib/widgets/gig_card.dart', 'r') as f:
    content = f.read()

old_left = """                        // Left: Rating + Heart
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
                            const SizedBox(width: 12),"""

new_left = """                        // Left: Rating + Heart
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFFFB33E), size: 14),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  gig.averageRating > 0 ? gig.averageRating.toStringAsFixed(1) : 'New',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFFB33E)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (gig.reviewCount > 0)
                                Flexible(
                                  child: Text(
                                    ' (${gig.reviewCount})',
                                    style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              const SizedBox(width: 6),"""
content = content.replace(old_left, new_left)

old_right = """                                  },
                                );
                              }
                            ),
                          ],
                        ),
                        
                        // Right: Price"""

new_right = """                                  },
                                );
                              }
                            ),
                          ],
                        ),
                        ),
                        
                        // Right: Price"""
content = content.replace(old_right, new_right)

with open('lib/widgets/gig_card.dart', 'w') as f:
    f.write(content)

print("Fixed GigCard bottom row layout")
