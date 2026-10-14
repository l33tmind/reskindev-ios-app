import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A short, quiet chime for gentle moments (like saving a service to the wishlist).
class SoftSound {
  static final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  static Future<void> chime() async {
    HapticFeedback.lightImpact();
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/soft_chime.wav'), volume: 0.6);
    } catch (e) {
      debugPrint('Chime failed: $e');
    }
  }
}
