import 'package:shared_preferences/shared_preferences.dart';

/// The level to celebrate now, or null. Celebrates only a rise above the
/// last celebrated level; the first check for an account ([lastCelebrated]
/// null) only records a starting point.
int? levelToCelebrate({
  required int? lastCelebrated,
  required int currentLevel,
}) => lastCelebrated != null && currentLevel > lastCelebrated
    ? currentLevel
    : null;

/// The last level each account celebrated on this device.
abstract final class CelebrationStore {
  static String _key(String userId) => 'celebrated_level.$userId';

  static Future<int?> lastCelebrated(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_key(userId));
    } catch (_) {
      return null;
    }
  }

  static Future<void> setLastCelebrated(String userId, int level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key(userId), level);
    } catch (_) {
      // Storage unavailable: worst case the next level celebrates again.
    }
  }
}
