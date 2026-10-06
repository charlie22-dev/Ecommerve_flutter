import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/config/supabase_config.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({GoTrueClient? auth}) : _auth = auth ?? Supabase.instance.client.auth;

  final GoTrueClient _auth;

  @override
  Stream<AuthUser?> authStateChanges() => _auth.onAuthStateChange.map((state) {
        final user = state.session?.user;
        return user == null ? null : AuthUser.fromSupabase(user);
      });

  @override
  AuthUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : AuthUser.fromSupabase(user);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// The `profiles` row and the welcome notification are created by the
  /// `on_auth_user_created` trigger (supabase/schema.sql) in the same
  /// transaction as the account itself, from the `display_name` passed here
  /// — so there's no second client write that can fail after the account
  /// already exists.
  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName},
      emailRedirectTo: kIsWeb ? null : SupabaseConfig.mobileRedirectUrl,
    );
    // With "Confirm email" enabled, Supabase returns a user but no session.
    // (It also returns a fake, identity-less user for an already-registered
    // email, so enumeration isn't possible — treated the same way.)
    return response.session != null ? SignUpResult.signedIn : SignUpResult.needsEmailConfirmation;
  }

  @override
  Future<void> signInWithGoogle() => _signInWithProvider(OAuthProvider.google);

  @override
  Future<void> signInWithFacebook() => _signInWithProvider(OAuthProvider.facebook);

  /// Opens the provider's consent page. On web the whole page redirects
  /// and comes back signed in. On Android it opens a browser tab that
  /// returns through the `com.bookverse.app://login-callback` deep link, so
  /// this waits for the resulting sign-in before reporting success.
  /// Each provider must be enabled under Authentication → Providers.
  Future<void> _signInWithProvider(OAuthProvider provider) async {
    final signedIn = kIsWeb
        ? null
        : _auth.onAuthStateChange
            .firstWhere((s) => s.event == AuthChangeEvent.signedIn)
            .timeout(const Duration(minutes: 5));
    final launched = await _auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? null : SupabaseConfig.mobileRedirectUrl,
      authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
    if (!launched) throw const AuthException('Could not open the sign-in page.', code: 'launch_failed');
    if (signedIn != null) await signedIn;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: kIsWeb ? null : SupabaseConfig.mobileRedirectUrl,
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
