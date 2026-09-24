import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    c = f.read()

old_func = """  Widget _buildQuickReplies(AuthProvider auth) {
    if (!auth.isFreelancer) return const SizedBox.shrink();

    final templates = [
      "Let's start a Google Meet call for better communication",
      "Hello! How can I help you?",
      "Let me check the details.",
      "Thanks for ordering!",
      "I'll deliver this soon.",
      "Could you provide more info?",
    ];

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: templates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(
              templates[index],
              style: TextStyle(
                fontSize: 13,
                color: context.themeTextDark,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: context.themeSurface,
            side: BorderSide(color: context.themeBorder),
            onPressed: () {
              _controller.text = templates[index];
              _sendMessage();
            },
          );
        },
      ),
    );
  }"""

new_func = """  Widget _buildQuickReplies(AuthProvider auth) {
    if (!auth.isFreelancer) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(auth.user?.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final savedReplies = List<String>.from(data?['quickReplies'] ?? []);
        
        final templates = savedReplies.isNotEmpty ? savedReplies : [
          "Let's start a Google Meet call for better communication",
          "Hello! How can I help you?",
          "Let me check the details.",
          "Thanks for ordering!",
          "I'll deliver this soon.",
          "Could you provide more info?",
        ];

        return Container(
          height: 40,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return ActionChip(
                label: Text(
                  templates[index],
                  style: TextStyle(
                    fontSize: 13,
                    color: context.themeTextDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                backgroundColor: context.themeSurface,
                side: BorderSide(color: context.themeBorder),
                onPressed: () {
                  _controller.text = templates[index];
                  _sendMessage();
                },
              );
            },
          ),
        );
      },
    );
  }"""

c = c.replace(old_func, new_func)

with open('lib/screens/chat_screen.dart', 'w') as f:
    f.write(c)

