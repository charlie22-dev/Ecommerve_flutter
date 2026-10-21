import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, AuthRetryableFetchException;

import '../domain/auth_repository.dart';

import 'auth_providers.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signIn(email: email, password: password),
    );
    state = result.hasError ? AsyncError(_message(result.error), StackTrace.current) : const AsyncData(null);
    return !result.hasError;
  }

  /// Null on failure (the error message is in `state`).
  Future<SignUpResult?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signUp(
            email: email,
            password: password,
            displayName: displayName,
          ),
    );
    state = result.hasError ? AsyncError(_message(result.error), StackTrace.current) : const AsyncData(null);
    return result.value;
  }

  Future<bool> signInWithGoogle() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signInWithGoogle());
    state = result.hasError ? AsyncError(_message(result.error), StackTrace.current) : const AsyncData(null);
    return !result.hasError;
  }

  Future<bool> signInWithFacebook() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signInWithFacebook());
    state = result.hasError ? AsyncError(_message(result.error), StackTrace.current) : const AsyncData(null);
    return !result.hasError;
  }

  Future<bool> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).sendPasswordResetEmail(email),
    );
    state = result.hasError ? AsyncError(_message(result.error), StackTrace.current) : const AsyncData(null);
    return !result.hasError;
  }

  Future<void> signOut() => ref.read(authRepositoryProvider).signOut();

  String _message(Object? error) {
    if (error is AuthRetryableFetchException || error is TimeoutException) {
      return 'Network error — check your connection.';
    }
    if (error is AuthException) {
      return switch (error.code) {
        'invalid_credentials' => 'Incorrect email or password.',
        'email_not_confirmed' => 'Please confirm your email first — check your inbox for the link.',
        'user_already_exists' || 'email_exists' => 'An account already exists with that email.',
        'weak_password' => 'Choose a stronger password (6+ characters).',
        'email_address_invalid' || 'validation_failed' => 'That email address looks invalid.',
        'user_banned' => 'This account has been disabled.',
        'signup_disabled' => 'New sign-ups are currently disabled.',
        'over_email_send_rate_limit' || 'over_request_rate_limit' =>
          'Email limit reached (free Supabase tier allows 3 emails/hr). Disable "Confirm email" in Supabase (Auth > Providers > Email) to sign up instantly.',
        'provider_disabled' => 'This sign-in method isn\'t enabled yet.',
        'launch_failed' => 'Could not open the sign-in page.',
        _ => error.message.isNotEmpty ? error.message : 'Something went wrong. Please try again.',
      };
    }
    return 'Something went wrong. Please try again.';
  }
}
