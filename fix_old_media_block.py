with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    content = f.read()

# Find start and end of the old StatefulBuilder media block
start_marker = "                    // ── SMART MEDIA URL FIELD ──────────────────────────\n                    StatefulBuilder("
# End should be right before `const SizedBox(height: 48)` and `// ── PACKAGE TIERS`
# We need to find the closing of the StatefulBuilder

start_idx = content.find(start_marker)
if start_idx == -1:
    print("Start marker not found")
else:
    # Find the end of the StatefulBuilder block - it ends with `),\n                    \n                    const SizedBox(height: 48)`
    end_marker = "                    ),\n                    \n                    const SizedBox(height: 48),"
    end_idx = content.find(end_marker, start_idx)
    if end_idx == -1:
        # Try alternative ending
        end_marker2 = "                    ),\n\n                    const SizedBox(height: 48),"
        end_idx = content.find(end_marker2, start_idx)
        if end_idx != -1:
            end_marker = end_marker2
    
    if end_idx != -1:
        # Replace the old block with nothing (remove it)
        after_block = end_marker[len("                    ),"):]  # Keep the const SizedBox part
        content = content[:start_idx] + "                    const SizedBox(height: 48)," + after_block + content[end_idx + len(end_marker):]
        with open('lib/screens/gig_editor_screen.dart', 'w') as f:
            f.write(content)
        print("Removed old StatefulBuilder media block")
    else:
        print(f"End marker not found. start_idx={start_idx}")
        # Show context around start
        print(repr(content[start_idx:start_idx+200]))
