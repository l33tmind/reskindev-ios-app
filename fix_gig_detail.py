with open('lib/screens/gig_detail_screen.dart', 'r') as f:
    content = f.read()

old_push = "context.push('/seller-profile/${gig.authorId}')"
new_push = "context.push('/seller-profile/${gig.authorId}', extra: {'fallbackName': gig.authorName, 'fallbackImage': gig.imageUrl})"

if old_push in content:
    content = content.replace(old_push, new_push)
    with open('lib/screens/gig_detail_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed gig_detail_screen push")
else:
    print("Could not find push in gig_detail_screen")
