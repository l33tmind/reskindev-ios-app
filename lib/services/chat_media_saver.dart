import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

/// Downloads a chat photo or video and saves it to the phone's Photos / Gallery.
/// Shows a small progress dialog while downloading and a SnackBar with the result.
Future<void> saveChatMediaToPhotos(BuildContext context, String url, {required bool isVideo}) async {
  if (url.isEmpty) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  void snack(String text) => messenger?.showSnackBar(SnackBar(content: Text(text)));

  try {
    if (!await Gal.hasAccess()) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        snack('Allow Reskindev to add to your Photos in Settings to save this.');
        return;
      }
    }
  } catch (e) {
    debugPrint('Gal access check failed: $e');
  }

  if (!context.mounted) return;
  var dialogOpen = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(color: ctx.themeSurface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(height: 14),
              Material(
                type: MaterialType.transparency,
                child: Text(isVideo ? 'Saving video…' : 'Saving photo…',
                    style: GoogleFonts.inter(fontSize: 14, color: ctx.themeTextDark)),
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(() => dialogOpen = false);

  File? tmp;
  try {
    final ext = _extensionFor(url, isVideo: isVideo);
    tmp = File('${Directory.systemTemp.path}/reskindev_${DateTime.now().millisecondsSinceEpoch}.$ext');

    // Stream to a temp file so big videos are not held in memory.
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      await res.pipe(tmp.openWrite());
    } finally {
      client.close();
    }

    if (isVideo) {
      await Gal.putVideo(tmp.path);
    } else {
      await Gal.putImage(tmp.path);
    }
    if (dialogOpen) navigator.pop();
    snack('Saved to Photos');
  } on GalException catch (e) {
    debugPrint('Gal save failed: ${e.type}');
    if (dialogOpen) navigator.pop();
    snack(e.type == GalExceptionType.accessDenied
        ? 'Allow Reskindev to add to your Photos in Settings to save this.'
        : e.type == GalExceptionType.notEnoughSpace
            ? 'Not enough space on your phone to save this.'
            : 'Could not save to Photos. Please try again.');
  } catch (e) {
    debugPrint('Chat media download failed: $e');
    if (dialogOpen) navigator.pop();
    snack('Could not download the file. Check your connection and try again.');
  } finally {
    try {
      if (tmp != null && await tmp.exists()) await tmp.delete();
    } catch (_) {}
  }
}

/// Long-press menu on a chat photo / video bubble.
void showSaveMediaSheet(BuildContext context, String url, {required bool isVideo}) {
  if (url.isEmpty) return;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.themeSurface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading: const Icon(Icons.download_rounded, color: AppTheme.primary),
          title: Text('Save to Photos',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: context.themeTextDark)),
          onTap: () {
            Navigator.pop(ctx);
            saveChatMediaToPhotos(context, url, isVideo: isVideo);
          },
        ),
      ),
    ),
  );
}

String _extensionFor(String url, {required bool isVideo}) {
  // Firebase Storage URLs encode the object path, e.g. .../o/chat_videos%2F...%2Fx.mov?alt=media
  final path = Uri.decodeComponent(Uri.tryParse(url)?.path ?? '').toLowerCase();
  final dot = path.lastIndexOf('.');
  final ext = dot >= 0 ? path.substring(dot + 1) : '';
  const imageExts = {'jpg', 'jpeg', 'png', 'heic', 'gif', 'webp'};
  const videoExts = {'mp4', 'mov', 'm4v'};
  if (isVideo) return videoExts.contains(ext) ? ext : 'mp4';
  return imageExts.contains(ext) ? ext : 'jpg';
}
