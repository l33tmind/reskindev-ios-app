import re

with open('lib/widgets/chat_bubble.dart', 'r') as f:
    content = f.read()

old_build = """  @override
  Widget build(BuildContext context) {
    if (message.type == 'offer') {
      return _buildOfferBubble(context);
    }
    if (message.type == 'admin_alert') {
      return _buildAdminAlert(context);
    }
    if (message.type == 'image') {
      return _buildImageBubble(context);
    }
    return _buildTextBubble(context);
  }"""

new_build = """  @override
  Widget build(BuildContext context) {
    if (message.type == 'system_notification') {
      return _buildSystemNotificationBubble(context);
    }
    if (message.type == 'offer') {
      return _buildOfferBubble(context);
    }
    if (message.type == 'admin_alert') {
      return _buildAdminAlert(context);
    }
    if (message.type == 'image') {
      return _buildImageBubble(context);
    }
    return _buildTextBubble(context);
  }
  
  Widget _buildSystemNotificationBubble(BuildContext context) {
    IconData icon;
    Color iconColor = AppTheme.primary;
    switch (message.actionType) {
      case 'order_placed':
        icon = Icons.work_outline;
        break;
      case 'requirements_submitted':
        icon = Icons.description_outlined;
        break;
      case 'order_delivered':
        icon = Icons.unarchive_outlined;
        break;
      case 'order_completed':
        icon = Icons.star_border_rounded;
        break;
      default:
        icon = Icons.info_outline;
    }

    return Align(
      alignment: Alignment.center,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.isDarkMode ? const Color(0xFF2D3748) : const Color(0xFFEDF2F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.themeBorder.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 12),
            Text(
              message.text,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.themeTextDark,
              ),
              textAlign: TextAlign.center,
            ),
            if (message.gigTitle != null && message.gigTitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                message.gigTitle!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: context.themeTextLight,
                ),
                textAlign: TextAlign.center,
              ),
            ]
          ],
        ),
      ),
    );
  }"""
content = content.replace(old_build, new_build)

with open('lib/widgets/chat_bubble.dart', 'w') as f:
    f.write(content)

print("Added System Notification rendering to ChatBubble")
