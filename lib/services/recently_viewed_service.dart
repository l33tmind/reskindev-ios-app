import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the ids of the gigs the user opened most recently (newest first).
class RecentlyViewedService {
  static const _key = 'recently_viewed_gigs';
  static const _maxItems = 12;

  /// Home screen listens to this to refresh when a gig is viewed.
  static final ValueNotifier<List<String>> ids = ValueNotifier<List<String>>([]);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      ids.value = prefs.getStringList(_key) ?? [];
    } catch (e) {
      debugPrint('Failed to load recently viewed: $e');
    }
  }

  static Future<void> add(String gigId) async {
    if (gigId.isEmpty) return;
    final list = [gigId, ...ids.value.where((id) => id != gigId)].take(_maxItems).toList();
    ids.value = list;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, list);
    } catch (e) {
      debugPrint('Failed to save recently viewed: $e');
    }
  }
}
