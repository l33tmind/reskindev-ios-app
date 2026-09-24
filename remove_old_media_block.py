with open('lib/screens/gig_editor_screen.dart', 'r') as f:
    content = f.read()

# Find and remove the old SMART MEDIA URL FIELD block (which still has _mediaCtrl)
start_marker = "                    // ── SMART MEDIA URL FIELD ──────────────────────────\n                    StatefulBuilder("
end_marker = "                    // ── GALLERY IMAGES"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx != -1 and end_idx != -1:
    # Remove old block (it should be followed by gallery section)
    content = content[:start_idx] + content[end_idx:]
    with open('lib/screens/gig_editor_screen.dart', 'w') as f:
        f.write(content)
    print("Removed old media block")
else:
    print(f"Could not find markers. start_idx={start_idx}, end_idx={end_idx}")
