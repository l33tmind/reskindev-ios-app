import re

with open('lib/screens/chat_screen.dart', 'r') as f:
    content = f.read()

methods = """
  Widget _buildQuickReplies(AuthProvider auth) {
    if (!auth.isFreelancer) return const SizedBox.shrink();
    
    final templates = [
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
            label: Text(templates[index], style: const TextStyle(fontSize: 12)),
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
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: context.themeSurface.withValues(alpha: 0.5),
      child: Row(
        children: [
          Container(width: 4, height: 40, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _replyingTo!.senderName,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary),
                ),
                Text(
                  _replyingTo!.text,
                  style: GoogleFonts.inter(fontSize: 12, color: context.themeTextDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }
"""

if "_buildQuickReplies" not in content:
    content = content.replace("  Widget _buildMessageInput() {", methods + "\n  Widget _buildMessageInput() {")
    with open('lib/screens/chat_screen.dart', 'w') as f:
        f.write(content)
    print("Methods added")
else:
    print("Already added")
