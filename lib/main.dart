import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/onboarding/launch_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final hasSeenSplash = await LaunchPrefs.loadHasSeenSplash();

  if (!SupabaseConfig.isConfigured) {
    debugPrint(
      'Supabase is not configured — set the URL and publishable key in '
      'lib/core/config/supabase_config.dart (see supabase/SETUP.md).',
    );
  }
  // Restores the saved session from local storage before the first frame,
  // so a returning user isn't bounced to Login on launch. Network-free, so
  // it doesn't block startup when offline.
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.publishableKey);

  runApp(ProviderScope(
    overrides: [hasSeenLaunchSplashProvider.overrideWith((ref) => hasSeenSplash)],
    child: const BookVerseApp(),
  ));
}
