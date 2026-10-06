import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/pending_return_location.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/reading_illustration.dart';
import '../domain/auth_repository.dart';
import 'auth_controller.dart';
import 'auth_validators.dart';
import 'login_success_dialog.dart';
import 'widgets/forgot_password_sheet.dart';

/// The unified Login / Sign up screen from login_basis.png — a single pill
/// toggle swaps the form between modes instead of two separate routes.
///
/// Login and Sign Up each keep their own `TextEditingController`s and their
/// own `GlobalKey<FormState>` — they used to share one set of controllers,
/// which meant typing an email in Login mode silently carried it over into
/// Sign Up (and vice versa) since it was, under the hood, the same text
/// field object. They're fully independent now.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();

  final _signupFormKey = GlobalKey<FormState>();
  final _signupName = TextEditingController();
  final _signupEmail = TextEditingController();
  final _signupPassword = TextEditingController();
  final _signupConfirmPassword = TextEditingController();

  bool _isLogin = true;
  bool _obscureLoginPassword = true;
  bool _obscureSignupPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _loginEmail.dispose();
    _loginPassword.dispose();
    _signupName.dispose();
    _signupEmail.dispose();
    _signupPassword.dispose();
    _signupConfirmPassword.dispose();
    super.dispose();
  }

  void _announceObscureChange(bool obscure) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      obscure ? 'Password hidden' : 'Password shown',
      TextDirection.ltr,
    );
  }

  Future<void> _submit() async {
    final controller = ref.read(authControllerProvider.notifier);
    final bool ok;

    if (_isLogin) {
      if (!_loginFormKey.currentState!.validate()) return;
      FocusScope.of(context).unfocus();
      ok = await controller.signIn(email: _loginEmail.text, password: _loginPassword.text);
    } else {
      if (!_signupFormKey.currentState!.validate()) return;
      FocusScope.of(context).unfocus();
      final email = _signupEmail.text.trim();
      final result = await controller.signUp(
        email: email,
        password: _signupPassword.text,
        displayName: _signupName.text.trim(),
      );
      if (result == SignUpResult.needsEmailConfirmation) {
        // The account exists but the Supabase project requires email
        // confirmation before the first login — not an error. Hand the
        // user over to the Login tab with their email filled in.
        if (!mounted) return;
        setState(() {
          _isLogin = true;
          _loginEmail.text = email;
        });
        _signupFormKey.currentState?.reset();
        _signupName.clear();
        _signupEmail.clear();
        _signupPassword.clear();
        _signupConfirmPassword.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text('Account created! We sent a confirmation link to $email — confirm it, then log in.'),
          ),
        );
        return;
      }
      ok = result != null;
    }

    if (ok && mounted) {
      await LoginSuccessDialog.show(context, isNewAccount: !_isLogin);
      _goToReturnLocation();
    } else if (!ok && !_isLogin && mounted) {
      // A failed sign-up (e.g. "account already exists with that email")
      // used to leave the whole form sitting there — most often what you
      // actually need to change is the email, but you'd have to notice
      // that yourself and manually clear every field. Wiping the form
      // makes the failure obvious and gets you back to a blank slate to
      // retry with different details.
      _signupFormKey.currentState?.reset();
      _signupName.clear();
      _signupEmail.clear();
      _signupPassword.clear();
      _signupConfirmPassword.clear();
    }
  }

  Future<void> _continueWithGoogle() async {
    final ok = await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (ok && mounted) {
      await LoginSuccessDialog.show(context, isNewAccount: false);
      _goToReturnLocation();
    }
  }

  Future<void> _continueWithFacebook() async {
    final ok = await ref.read(authControllerProvider.notifier).signInWithFacebook();
    if (ok && mounted) {
      await LoginSuccessDialog.show(context, isNewAccount: false);
      _goToReturnLocation();
    }
  }

  /// Sends the user back to whichever page prompted the login (captured in
  /// require_login.dart / app_router.dart's redirect), falling back to
  /// Home. Deliberately explicit and tied to the "Got it" tap rather than
  /// left to the router's own auth-state-triggered redirect — that redirect
  /// runs off the Supabase auth stream emitting, which is not guaranteed to
  /// land before this handler runs, so relying on it alone was a race that
  /// could leave the underlying page on /auth (or bounce to Home) instead
  /// of the intended destination. This call is the deterministic one.
  void _goToReturnLocation() {
    if (!mounted) return;
    final target = ref.read(pendingReturnLocationProvider);
    ref.read(pendingReturnLocationProvider.notifier).state = null;
    context.go(target ?? AppRoute.home);
  }

  void _forgotPassword() {
    ForgotPasswordSheet.show(context, initialEmail: _loginEmail.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error.toString()), backgroundColor: context.colors.error),
        );
      }
    });

    return Scaffold(
      backgroundColor: context.colors.authBackground,
      // Guests can browse the whole app now (see app_router.dart) and land
      // here either by choice (Me screen's "Sign In" button) or by being
      // redirected off a gated screen (Notifications, Cart, …) — either
      // way they need a way back that isn't "stuck on the login screen".
      // `canPop` covers a deliberate push (pops back to wherever they
      // came from); the redirect case doesn't leave a pop-able entry, so
      // it falls back to Home, which is always a safe, guest-accessible
      // destination.
      appBar: AppBar(
        backgroundColor: context.colors.authBackground,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: 'Back',
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.colors.textPrimary),
            onPressed: () => context.canPop() ? context.pop() : context.go(AppRoute.home),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: ReadingIllustration()),
                const SizedBox(height: 20),
                Text(
                  _isLogin ? 'Welcome back \u{1F44B}' : 'Create your account ✨',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  _isLogin
                      ? 'Enter your details to access your account'
                      : "Let's get your shelf set up",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),
                _ModeToggle(
                  isLogin: _isLogin,
                  onChanged: (value) => setState(() => _isLogin = value),
                ),
                const SizedBox(height: 24),
                if (_isLogin) _buildLoginForm(context) else _buildSignupForm(context),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: _isLogin ? 'Login' : 'Sign up',
                  isLoading: authState.isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Divider(color: context.colors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or continue with', style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: context.colors.border)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SocialButton(
                        label: 'Google',
                        isLoading: authState.isLoading,
                        onPressed: _continueWithGoogle,
                        icon: const _GoogleGlyph(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SocialButton(
                        label: 'Facebook',
                        isLoading: authState.isLoading,
                        onPressed: _continueWithFacebook,
                        icon: const Icon(Icons.facebook_rounded, color: Color(0xFF1877F2), size: 22),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel('Email'),
          TextFormField(
            controller: _loginEmail,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            style: TextStyle(color: context.colors.textPrimary),
            decoration: const InputDecoration(hintText: 'you@example.com'),
            validator: AuthValidators.email,
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Password'),
          TextFormField(
            controller: _loginPassword,
            obscureText: _obscureLoginPassword,
            autofillHints: const [AutofillHints.password],
            style: TextStyle(color: context.colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter your password',
              suffixIcon: IconButton(
                tooltip: _obscureLoginPassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscureLoginPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: context.colors.textTertiary,
                ),
                onPressed: () {
                  setState(() => _obscureLoginPassword = !_obscureLoginPassword);
                  _announceObscureChange(_obscureLoginPassword);
                },
              ),
            ),
            validator: AuthValidators.password,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _forgotPassword,
              style: TextButton.styleFrom(foregroundColor: context.colors.textPrimary),
              child: const Text('Forgot Password'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupForm(BuildContext context) {
    return Form(
      key: _signupFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel('Display name'),
          TextFormField(
            controller: _signupName,
            autofillHints: const [AutofillHints.name],
            style: TextStyle(color: context.colors.textPrimary),
            decoration: const InputDecoration(hintText: 'How should we call you?'),
            validator: AuthValidators.displayName,
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Email'),
          TextFormField(
            controller: _signupEmail,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.newUsername],
            style: TextStyle(color: context.colors.textPrimary),
            decoration: const InputDecoration(hintText: 'you@example.com'),
            validator: AuthValidators.email,
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Password'),
          TextFormField(
            controller: _signupPassword,
            obscureText: _obscureSignupPassword,
            autofillHints: const [AutofillHints.newPassword],
            style: TextStyle(color: context.colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'At least 6 characters',
              suffixIcon: IconButton(
                tooltip: _obscureSignupPassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscureSignupPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: context.colors.textTertiary,
                ),
                onPressed: () {
                  setState(() => _obscureSignupPassword = !_obscureSignupPassword);
                  _announceObscureChange(_obscureSignupPassword);
                },
              ),
            ),
            validator: AuthValidators.password,
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Confirm password'),
          TextFormField(
            controller: _signupConfirmPassword,
            obscureText: _obscureConfirmPassword,
            style: TextStyle(color: context.colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Re-enter your password',
              suffixIcon: IconButton(
                tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: context.colors.textTertiary,
                ),
                onPressed: () {
                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                  _announceObscureChange(_obscureConfirmPassword);
                },
              ),
            ),
            validator: AuthValidators.confirmPassword(() => _signupPassword.text),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        label,
        style: TextStyle(color: context.colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.isLoading,
  });

  final String label;
  final Widget icon;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: context.colors.textPrimary,
        side: BorderSide(color: context.colors.border),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

/// A simple lettermark stand-in for Google's logo — Flutter's Material
/// icon set has no official Google "G" glyph (the real mark is a
/// trademarked asset), so this keeps the button recognizable without
/// bundling one.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w900, fontSize: 16, height: 1),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.isLogin, required this.onChanged});

  final bool isLogin;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Expanded(child: _segment(context, 'Login', true)),
          Expanded(child: _segment(context, 'Sign up', false)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, bool value) {
    final selected = isLogin == value;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected ? context.colors.authBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? context.colors.textPrimary : context.colors.textSecondary,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
