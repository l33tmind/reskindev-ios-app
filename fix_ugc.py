import re

with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    content = f.read()

old_block = """                        const SizedBox(height: 16),
                        _buildTextField(_youtubeCtrl, 'YouTube Video URL (Optional)', 'e.g. https://youtu.be/...'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── PACKAGE TIERS (TABS) ──────────────────────────"""

new_block = """                        const SizedBox(height: 16),
                        _buildTextField(_youtubeCtrl, 'YouTube Video URL (Optional)', 'e.g. https://youtu.be/...'),
                        const SizedBox(height: 16),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _youtubeCtrl,
                          builder: (context, value, child) {
                            if (_uploadedImageUrl.isNotEmpty || value.text.trim().isNotEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                                ),
                                child: CheckboxListTile(
                                  value: _ugcAccepted,
                                  onChanged: (val) {
                                    setState(() => _ugcAccepted = val ?? false);
                                  },
                                  title: Text(
                                    'Mandatory UGC & Copyright Declaration',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.red.shade700),
                                  ),
                                  subtitle: Text(
                                    'I declare that the media uploaded or linked above is my original work, and I have the rights to use it.',
                                    style: GoogleFonts.inter(fontSize: 12, color: context.themeTextDark),
                                  ),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  activeColor: Colors.red.shade700,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── PACKAGE TIERS (TABS) ──────────────────────────"""

if old_block in content:
    content = content.replace(old_block, new_block)
    with open('lib/screens/gig_editor_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed UGC Checkbox")
else:
    print("Could not find UGC block")
