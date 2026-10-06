import 'auth_user.dart';

/// Outcome of a sign-up: either the user is signed in straight away, or
/// the Supabase project has "Confirm email" on and they must click the
/// link in their inbox before they can log in.
enum SignUpResult { signedIn, needsEmailConfirmation }

abstract class AuthRepository {
  Stream<AuthUser?> authStateChanges();

  AuthUser? get currentUser;

  Future<void> signIn({required String email, required String password});

  Future<SignUpResult> signUp({required String email, required String password, required String displayName});

  Future<void> signInWithGoogle();

  Future<void> signInWithFacebook();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();
}
