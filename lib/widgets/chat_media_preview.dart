import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

/// Full-screen preview of a picked photo or video before it is sent in the chat.
/// Returns true when the person taps Send.
Future<bool> showChatMediaPreview(
  BuildContext context, {
  required XFile file,
  required bool isVideo,
  required int maxBytes,
  required String tooLargeMessage,
}) async {
  final sizeBytes = await file.length();
  if (!context.mounted) return false;
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ChatMediaPreview(
        file: file,
        isVideo: isVideo,
        sizeBytes: sizeBytes,
        tooLarge: sizeBytes > maxBytes,
        tooLargeMessage: tooLargeMessage,
      ),
    ),
  );
  return result == true;
}

String formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes B';
}

class _ChatMediaPreview extends StatefulWidget {
  final XFile file;
  final bool isVideo;
  final int sizeBytes;
  final bool tooLarge;
  final String tooLargeMessage;

  const _ChatMediaPreview({
    required this.file,
    required this.isVideo,
    required this.sizeBytes,
    required this.tooLarge,
    required this.tooLargeMessage,
  });

  @override
  State<_ChatMediaPreview> createState() => _ChatMediaPreviewState();
}

class _ChatMediaPreviewState extends State<_ChatMediaPreview> {
  static const _sendGreen = Color(0xFF16A34A);
  VideoPlayerController? _video;
  bool _videoFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      final c = VideoPlayerController.file(File(widget.file.path));
      _video = c;
      c.addListener(_onTick);
      c.initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((Object e) {
        debugPrint('Preview video failed: $e');
        if (mounted) setState(() => _videoFailed = true);
      });
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _video?.removeListener(_onTick);
    _video?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _video;
    if (c == null || !c.value.isInitialized) return;
    c.value.isPlaying ? c.pause() : c.play();
  }

  Widget _buildMedia() {
    if (!widget.isVideo) {
      return InteractiveViewer(
        maxScale: 4,
        child: Image.file(
          File(widget.file.path),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.white54, size: 48),
        ),
      );
    }
    final c = _video!;
    if (_videoFailed) {
      return Text('Could not preview this video', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14));
    }
    if (!c.value.isInitialized) return const CircularProgressIndicator(color: Colors.white);
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
          if (!c.value.isPlaying)
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 42),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              c,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              colors: const VideoProgressColors(
                playedColor: _sendGreen,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: close + file size
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  const Spacer(),
                  Icon(widget.isVideo ? Icons.videocam_outlined : Icons.photo_outlined, color: Colors.white54, size: 16),
                  const SizedBox(width: 6),
                  Text(formatFileSize(widget.sizeBytes), style: GoogleFonts.inter(color: Colors.white70, fontSize: 12.5)),
                ],
              ),
            ),
            Expanded(child: Center(child: _buildMedia())),
            if (widget.tooLarge)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(widget.tooLargeMessage,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13, height: 1.35)),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Cancel', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: widget.tooLarge ? null : () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _sendGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white12,
                        disabledForegroundColor: Colors.white38,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 20),
                      label: Text('Send', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
