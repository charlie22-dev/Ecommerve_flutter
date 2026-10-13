import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/app_routes.dart';
import 'login_success_dialog.dart';

/// Web only: Google/Facebook sign-in leaves the page and reloads the app,
/// so the login screen that started it is gone by the time the user is
/// actually signed in. Note it (with where to return) before leaving, then
/// show the success popup once the reloaded app has a session.
abstract final class OAuthReturn {
  static const _key = 'oauth_return_location'; // '' = Home

  static Future<void> markPending(String? returnLocation) async {
    await (await SharedPreferences.getInstance()).setString(_key, returnLocation ?? '');
  }

  static Future<void> clear() async => (await SharedPreferences.getInstance()).remove(_key);

  /// Run once after the app's first frame.
  static Future<void> completeIfPending(GoRouter router) async {
    final prefs = await SharedPreferences.getInstance();
    final target = prefs.getString(_key);
    if (target == null) return;
    await prefs.remove(_key); // one shot, even if sign-in was cancelled

    final auth = Supabase.instance.client.auth;
    final signedIn = auth.currentSession != null ||
        await auth.onAuthStateChange
            .map((s) => s.session != null)
            .firstWhere((hasSession) => hasSession, orElse: () => false)
            .timeout(const Duration(seconds: 10), onTimeout: () => false);
    if (!signedIn) return; // cancelled at Google/Facebook, or it failed

    final context = router.routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await LoginSuccessDialog.show(context, isNewAccount: false);
    router.go(target.isEmpty ? AppRoute.home : target);
  }
}
