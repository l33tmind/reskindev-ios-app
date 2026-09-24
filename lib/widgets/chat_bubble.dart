import 'package:any_link_preview/any_link_preview.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/chat_models.dart';
import '../theme.dart';

class ChatBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool isRead;
  final bool isFreelancer;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isFreelancer = false,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.isRead = false,
  });

  @override
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
      case 'requirements':
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
  }

  Widget _buildTextBubble(BuildContext context) {
    final urlRegExp = RegExp(r'(https?:\/\/[^\s]+)');
    final match = urlRegExp.firstMatch(message.text);
    final link = match?.group(0);
    final isOnlyLink = link != null && message.text.trim() == link;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: isFirstInGroup ? 8 : 2),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? AppTheme.primary : context.themeSurface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : (isLastInGroup ? 4 : 18)),
                bottomRight: Radius.circular(!isMe ? 18 : (isLastInGroup ? 4 : 18)),
              ),
              border: isMe ? null : Border.all(color: context.themeBorder.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.replyToText != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border(left: BorderSide(color: isMe ? Colors.white : AppTheme.primary, width: 3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.replyToSender ?? '',
                          style: GoogleFonts.inter(
                            color: isMe ? Colors.white : AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          message.replyToText!,
                          style: GoogleFonts.inter(
                            color: isMe ? Colors.white : context.themeTextDark,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
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
                if (!isOnlyLink)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 2),
                    child: Text(
                      message.text,
                      style: GoogleFonts.inter(
                        color: isMe ? Colors.white : context.themeTextDark,
                        fontSize: 15,
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.createdAt != null
                          ? DateFormat('hh:mm a').format(message.createdAt!)
                          : 'Sending...',
                      style: GoogleFonts.inter(
                        color: isMe ? Colors.white.withOpacity(0.7) : context.themeTextLight,
                        fontSize: 10,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.createdAt == null
                            ? Icons.access_time
                            : (isRead ? Icons.done_all : Icons.check),
                        size: 14,
                        color: isRead ? Colors.blue.shade200 : Colors.white.withOpacity(0.7),
                      ),
                    ]
                  ],
                ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }  Widget _buildImageBubble(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: isFirstInGroup ? 8 : 1,
          bottom: isLastInGroup ? 8 : 1,
          left: 16,
          right: 16,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : context.themeSurface,
          borderRadius: BorderRadius.circular(16),
          border: isMe ? null : Border.all(color: context.themeBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: message.imageUrl ?? '',
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(height: 200, color: Colors.grey.withOpacity(0.2)),
                errorWidget: (context, url, error) => Container(height: 150, color: Colors.grey.withOpacity(0.2), child: const Icon(Icons.broken_image)),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.createdAt != null
                            ? DateFormat('hh:mm a').format(message.createdAt!)
                            : 'Sending...',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.createdAt == null
                              ? Icons.access_time
                              : (isRead ? Icons.done_all : Icons.check),
                          size: 14,
                          color: isRead ? Colors.lightBlueAccent : Colors.white.withOpacity(0.7),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfferBubble(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.75,
        margin: EdgeInsets.only(
          top: isFirstInGroup ? 8 : 1,
          bottom: isLastInGroup ? 8 : 1,
          left: 16,
          right: 16,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.themeSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Custom Offer',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message.offerDescription ?? message.text,
              style: GoogleFonts.inter(color: context.themeTextDark, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Price', style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
                    Text('\$${message.offerPrice ?? 0}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: context.themeTextDark)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Delivery', style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
                    Text('${message.offerDays ?? 0} Days', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: context.themeTextDark)),
                  ],
                ),
              ],
            ),
            if (!isMe) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Proceeding to checkout... (UI pending)')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Accept Offer', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildAdminAlert(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber),
        ),
        child: Text(
          message.text,
          style: GoogleFonts.inter(
            color: Colors.amber.shade900,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
