with open('lib/screens/home_screen.dart', 'r') as f:
    lines = f.readlines()

new_lines = []
skip = False
for i, line in enumerate(lines):
    if "widget.gig.title," in line and "Text(" in lines[i-1]:
        # Keep the title
        new_lines.append(line)
        continue
    
    if "const SizedBox(height: 6)," in line and "Row(" in lines[i+1]:
        skip = True
        
        replacement = """                      const Spacer(),
                      
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
                                widget.gig.averageRating > 0 ? widget.gig.averageRating.toStringAsFixed(1) : 'New',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFFB33E)),
                              ),
                              if (widget.gig.reviewCount > 0)
                                Text(
                                  ' (${widget.gig.reviewCount})',
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
                                '\\$${price.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: context.themeTextDark),
                              ),
                            ],
                          ),
                        ],
                      ),\n"""
        new_lines.append(replacement)
        continue
        
    if skip and "], // children of outer Column" in line:
        pass # this won't happen, we need to find where to stop skipping

    if skip:
        if "], // children of Card Column" in line:
            pass
        if "], // Column children" in line:
            pass
        if "                    ]," in line and "                  )," in lines[i+1]:
            skip = False
            new_lines.append(line)
        continue

    if not skip:
        new_lines.append(line)

with open('lib/screens/home_screen.dart', 'w') as f:
    f.writelines(new_lines)
print("Updated home_screen.dart")
