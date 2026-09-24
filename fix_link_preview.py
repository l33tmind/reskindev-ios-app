import re

with open('lib/widgets/chat_bubble.dart', 'r') as f:
    content = f.read()

# 1. Remove AnyLinkPreview from outside the Container
old_outside = """          ),
          if (link != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 250),
                child: AnyLinkPreview(
                  link: link,
                  displayDirection: UIDirection.uiDirectionVertical,
                  showMultimedia: true,
                  bodyMaxLines: 3,
                  bodyTextOverflow: TextOverflow.ellipsis,
                  titleStyle: GoogleFonts.inter(
                    color: context.themeTextDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  bodyStyle: GoogleFonts.inter(
                    color: context.themeTextLight,
                    fontSize: 11,
                  ),
                  backgroundColor: context.themeSurface,
                  borderRadius: 12,
                  removeElevation: true,
                ),
              ),
            ),
        ],
      ),
    );"""

new_outside = """          ),
        ],
      ),
    );"""
content = content.replace(old_outside, new_outside)


# 2. Insert AnyLinkPreview INSIDE the bubble
old_wrap = """                  ),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 2),
                  child: Text(
                    message.text,"""

new_wrap = """                  ),
                if (link != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: IgnorePointer(
                      ignoring: false,
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.themeSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.themeBorder.withValues(alpha: 0.5)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: AnyLinkPreview(
                          link: link,
                          displayDirection: UIDirection.uiDirectionVertical,
                          showMultimedia: true,
                          bodyMaxLines: 2,
                          bodyTextOverflow: TextOverflow.ellipsis,
                          titleStyle: GoogleFonts.inter(
                            color: context.themeTextDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          bodyStyle: GoogleFonts.inter(
                            color: context.themeTextLight,
                            fontSize: 11,
                          ),
                          backgroundColor: context.themeSurface,
                          borderRadius: 0,
                          removeElevation: true,
                        ),
                      ),
                    ),
                  ),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 2),
                  child: Text(
                    message.text,"""
content = content.replace(old_wrap, new_wrap)

with open('lib/widgets/chat_bubble.dart', 'w') as f:
    f.write(content)

print("Moved LinkPreview inside the Chat Bubble")
