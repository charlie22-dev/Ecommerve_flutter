import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'has_seen_launch_splash_v1';

/// Whether the first-launch splash/ad screen has already been shown on
/// this install. Overridden at bootstrap in main.dart with the real value
/// read from SharedPreferences *before* `runApp` — the router's redirect
/// needs this synchronously (same reasoning as Supabase `auth.currentUser`
/// in app_router.dart), so it can't be an async provider read at redirect
/// time the way `themeModeProvider` is.
final hasSeenLaunchSplashProvider = StateProvider<bool>((ref) => false);

class LaunchPrefs {
  static Future<bool> loadHasSeenSplash() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  static Future<void> markSplashSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }
}
