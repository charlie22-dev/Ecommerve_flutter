import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Debug-only bypass so the app shell can be previewed before a real
/// Supabase project is wired up (see supabase/SETUP.md). Only
/// ever surfaced from `LoginScreen` behind `kDebugMode`, and never used to
/// gate anything security-sensitive — with no `uid`, every database query
/// in guest mode just falls back to its already-existing "not signed in"
/// empty state.
///
/// Remove this file and its two call sites (`app_router.dart`'s redirect,
/// `login_screen.dart`'s guest button) once real Supabase Auth is in place
/// and you no longer need an auth-free preview path.
final devGuestModeProvider = StateProvider<bool>((ref) => false);
