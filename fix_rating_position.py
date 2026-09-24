def update_card(filename):
    with open(filename, 'r') as f:
        content = f.read()

    # We need to move `const Spacer(),` from BEFORE the Rating Row to AFTER it.
    
    # In gig_card.dart:
    #                     const Spacer(),
    #                     
    #                     // Rating
    #                     Row(
    # ...
    #                     ),
    #                     
    #                     const SizedBox(height: 8),
    #                     Divider(height: 1, color: context.themeBorder.withOpacity(0.5)),

    # Let's use regex or string replace.
    
    block_to_find = """                    const Spacer(),
                    
                    // Rating
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFFB33E), size: 16),
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
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    Divider"""

    block_to_replace = """                    const SizedBox(height: 8),
                    
                    // Rating
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFFB33E), size: 16),
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
                      ],
                    ),
                    
                    const Spacer(),
                    
                    const SizedBox(height: 8),
                    Divider"""

    if block_to_find in content:
        content = content.replace(block_to_find, block_to_replace)
    else:
        print(f"Could not find exact block in {filename} (gig_card.dart version)")
        
        # Try the web version which uses widget.gig
        block_to_find_web = block_to_find.replace('gig.', 'widget.gig.')
        block_to_replace_web = block_to_replace.replace('gig.', 'widget.gig.')
        
        if block_to_find_web in content:
            content = content.replace(block_to_find_web, block_to_replace_web)
        else:
            print(f"Could not find exact block in {filename} (web version)")

    with open(filename, 'w') as f:
        f.write(content)

update_card('lib/widgets/gig_card.dart')
update_card('lib/screens/home_screen.dart')
