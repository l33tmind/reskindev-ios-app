with open('lib/screens/gig_detail_screen.dart', 'r') as f:
    content = f.read()

old_author = """              OutlinedButton(
                onPressed: () => context.push('/seller-profile/${gig.authorId}'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('View Profile'),
              )
            ],
          ),
        ],
      ),
    );
  }"""

new_author = """            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/seller-profile/${gig.authorId}'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.themeBorder),
                    foregroundColor: context.themeTextDark,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('View Profile'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      context.push("/login");
                    } else if (user.uid != gig.authorId) {
                      context.push('/chat/new', extra: {
                        'targetUserId': gig.authorId,
                        'targetUserName': gig.authorName.isNotEmpty ? gig.authorName : 'Verified Seller',
                        'targetUserAvatar': '',
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('You cannot message yourself.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: const Text('Contact Me'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }"""

content = content.replace(old_author, new_author)

with open('lib/screens/gig_detail_screen.dart', 'w') as f:
    f.write(content)
print("Updated author section")
