import 'package:any_link_preview/any_link_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
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
    if (message.type == 'video') {
      return _buildVideoBubble(context);
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
          color: context.isDarkMode
              ? const Color(0xFF2D3748)
              : const Color(0xFFEDF2F7),
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
            ],
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
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? AppTheme.primary : context.themeSurface,
              boxShadow: [
                BoxShadow(
                  color: isMe
                      ? AppTheme.primary.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: isMe ? 12 : 3,
                  spreadRadius: isMe ? -4 : 0,
                  offset: Offset(0, isMe ? 5 : 1),
                ),
              ],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(
                  isMe ? 20 : (isLastInGroup ? 6 : 20),
                ),
                bottomRight: Radius.circular(
                  !isMe ? 20 : (isLastInGroup ? 6 : 20),
                ),
              ),
              border: isMe
                  ? null
                  : Border.all(
                      color: context.themeTextDark.withValues(alpha: 0.06),
                    ),
            ),
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.replyToText != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.white.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border(
                        left: BorderSide(
                          color: isMe ? Colors.white : AppTheme.primary,
                          width: 3,
                        ),
                      ),
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
                          border: Border.all(
                            color: context.themeBorder.withValues(alpha: 0.5),
                          ),
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
                        child: SelectableText(
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
                              ? DateFormat('h:mm a').format(message.createdAt!)
                              : 'Sending...',
                          style: GoogleFonts.inter(
                            color: isMe
                                ? Colors.white.withOpacity(0.7)
                                : context.themeTextLight,
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
                            color: isRead
                                ? Colors.blue.shade200
                                : Colors.white.withOpacity(0.7),
                          ),
                        ],
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
  }

  /// Video message: a dark card with a play button. Tapping opens the full-screen player.
  Widget _buildVideoBubble(BuildContext context) {
    final url = message.videoUrl ?? '';
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: url.isEmpty ? null : () => openChatVideoPlayer(context, url),
        child: Container(
          margin: EdgeInsets.only(
            top: isFirstInGroup ? 8 : 1,
            bottom: isLastInGroup ? 8 : 1,
            left: 16,
            right: 16,
          ),
          width: 230,
          height: 150,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1F2937), Color(0xFF111827)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: isMe ? null : Border.all(color: context.themeBorder),
          ),
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 10,
                child: Row(
                  children: [
                    const Icon(Icons.videocam_rounded, color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text('Video', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Row(
                  children: [
                    Text(
                      message.createdAt != null ? DateFormat('h:mm a').format(message.createdAt!) : 'Sending...',
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 10),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.createdAt == null
                            ? Icons.access_time
                            : (isRead ? Icons.done_all : Icons.check),
                        size: 14,
                        color: isRead ? Colors.lightBlueAccent : Colors.white70,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageBubble(BuildContext context) {
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
          maxHeight: 340,
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
              GestureDetector(
                onTap: (message.imageUrl ?? '').isEmpty
                    ? null
                    : () => openChatImageViewer(context, message.imageUrl!),
                child: CachedNetworkImage(
                  imageUrl: message.imageUrl ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 200,
                    width: 200,
                    color: Colors.grey.withOpacity(0.2),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 150,
                    width: 200,
                    color: Colors.grey.withOpacity(0.2),
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.createdAt != null
                            ? DateFormat('h:mm a').format(message.createdAt!)
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
                          color: isRead
                              ? Colors.lightBlueAccent
                              : Colors.white.withOpacity(0.7),
                        ),
                      ],
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.themeSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: context.themeTextDark.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 28,
              spreadRadius: -10,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_offer_rounded,
                    color: AppTheme.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Custom Offer',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: context.themeTextDark,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message.offerDescription ?? message.text,
              style: GoogleFonts.inter(
                color: context.themeTextDark,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.themeTextLight,
                      ),
                    ),
                    Text(
                      '\$${message.offerPrice ?? 0}',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 24,
                        letterSpacing: -0.3,
                        color: context.themeTextDark,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Delivery',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.themeTextLight,
                      ),
                    ),
                    Text(
                      '${message.offerDays ?? 0} Days',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: context.themeTextDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (!isMe) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Proceeding to checkout... (UI pending)'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    'Accept Offer',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
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

/// Opens a chat photo full screen. Pinch to zoom, tap the close button to go back.
void openChatImageViewer(BuildContext context, String imageUrl) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => _ChatImageViewer(imageUrl: imageUrl),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _ChatImageViewer extends StatelessWidget {
  final String imageUrl;
  const _ChatImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (_, _, _) => const Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a chat video in a full-screen player (tap to play / pause, progress bar, close button).
void openChatVideoPlayer(BuildContext context, String videoUrl) {
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ChatVideoPlayer(videoUrl: videoUrl),
    ),
  );
}

class _ChatVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _ChatVideoPlayer({required this.videoUrl});

  @override
  State<_ChatVideoPlayer> createState() => _ChatVideoPlayerState();
}

class _ChatVideoPlayerState extends State<_ChatVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // The app is portrait only; allow landscape while watching a video.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller.play();
    }).catchError((Object e) {
      debugPrint('Chat video failed to load: $e');
      if (mounted) setState(() => _failed = true);
    });
    _controller.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _togglePlay() {
    if (!_controller.value.isInitialized) return;
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    final v = _controller.value;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlay,
                child: Center(
                  child: _failed
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 44),
                            const SizedBox(height: 8),
                            Text('Could not play this video',
                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                          ],
                        )
                      : v.isInitialized
                          ? AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(_controller))
                          : const CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
            if (v.isInitialized && !v.isPlaying && !_failed)
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 44),
                  ),
                ),
              ),
            if (v.isInitialized)
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: Row(
                  children: [
                    Text(_fmt(v.position), style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        colors: VideoProgressColors(
                          playedColor: AppTheme.primary,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(_fmt(v.duration), style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }
}
