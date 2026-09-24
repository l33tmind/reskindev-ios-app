with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

# Remove the duplicate old footer block (from the original replace_file that left artifacts)
old_duplicate = """                        ],
                      ),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(height: 8),
                      Divider(height: 1, color: context.themeBorder.withOpacity(0.5)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.favorite_border_rounded, size: 16, color: context.themeTextLight),
                          Row(
                            children: [
                              Text('From ', style: GoogleFonts.inter(fontSize: 10, color: context.themeTextLight, fontWeight: FontWeight.w500)),
                              Text(
                                '\\$${price.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: context.themeTextDark),
                              ),
                            ],
                          ),
                        ],
                      ),"""

replacement = """                        ],
                      ),"""

if old_duplicate in content:
    content = content.replace(old_duplicate, replacement)
    with open('lib/screens/home_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed duplicate footer in home_screen.dart")
else:
    print("Could not find duplicate footer block")
