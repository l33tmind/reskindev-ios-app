with open('lib/screens/chat_screen.dart', 'r') as f:
    c = f.read()

old_input = """                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.themeBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: context.themeBorder.withValues(alpha: 0.5),
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.newline,
                        minLines: 1,
                        maxLines: 5,
                        style: GoogleFonts.inter(color: context.themeTextDark),
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          hintStyle: GoogleFonts.inter(
                            color: context.themeTextLight,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),"""

new_input = """                  IconButton(
                    icon: Icon(Icons.add_circle_outline_rounded, color: context.themeTextLight),
                    onPressed: () {}, // Future: attachment
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.themeBackground, // Using theme background which is greyish/softer
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.newline,
                        minLines: 1,
                        maxLines: 5,
                        style: GoogleFonts.inter(color: context.themeTextDark),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: GoogleFonts.inter(
                            color: context.themeTextLight,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),"""

c = c.replace(old_input, new_input)
with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(c)
