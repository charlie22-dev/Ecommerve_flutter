/// Supabase project credentials — Dashboard → Project Settings → API (or
/// "Connect" → Mobile frameworks → Flutter).
///
/// The publishable key (older projects call it the "anon" key — either
/// works) is designed to ship inside the app: every table
/// is protected by Row Level Security (supabase/schema.sql), so it only
/// grants what those policies allow. NEVER put the service_role / secret key
/// here.
///
/// Values can also be overridden at build time:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lmzziooisjhioupwyuxp.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_N2A_BqulRXNk2iFAHU-Sbg_6OlU24v4',
  );

  static bool get isConfigured => !url.contains('YOUR-PROJECT-REF') && publishableKey != 'YOUR-PUBLISHABLE-KEY';

  /// Deep link the OAuth (Google/Facebook) and password-reset flows return
  /// to on Android — registered in AndroidManifest.xml and must also be
  /// added under Authentication → URL Configuration → Redirect URLs.
  static const mobileRedirectUrl = 'com.bookverse.app://login-callback';
}
