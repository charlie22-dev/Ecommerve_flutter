import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/pending_return_location.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/primary_button.dart';
import '../../admin/presentation/admin_providers.dart';
import '../domain/auth_repository.dart';
import 'auth_controller.dart';
import 'auth_validators.dart';
import 'login_success_dialog.dart';
import 'oauth_return.dart';
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
        if (!mounted) return;
        _showEmailVerificationSheet(context, email);
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

  Future<void> _continueWithGoogle() =>
      _continueWithProvider(() => ref.read(authControllerProvider.notifier).signInWithGoogle());

  Future<void> _continueWithProvider(Future<bool> Function() signIn) async {
    // On web the page leaves for Google/Facebook and the app reloads, so
    // "ok" here only means the redirect started; OAuthReturn shows the
    // popup after the reload, once the user really is signed in.
    if (kIsWeb) await OAuthReturn.markPending(ref.read(pendingReturnLocationProvider));
    final ok = await signIn();
    if (kIsWeb) {
      if (!ok) await OAuthReturn.clear();
      return;
    }
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
    final isAdmin = ref.read(isAdminProvider);
    if (isAdmin) {
      context.go(AppRoute.admin);
      return;
    }
    final target = ref.read(pendingReturnLocationProvider);
    ref.read(pendingReturnLocationProvider.notifier).state = null;
    context.go(target ?? AppRoute.home);
  }

  void _showEmailVerificationSheet(BuildContext context, String email) {
    final codeController = TextEditingController();
    bool isVerifying = false;
    bool isResending = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                MediaQuery.of(context).viewInsets.bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.colors.ink.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.mark_email_read_rounded, color: context.colors.ink, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verify Your Email',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Enter the 6-digit code sent to\n$email',
                              style: TextStyle(color: context.colors.textSecondary, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                    decoration: InputDecoration(
                      hintText: '000000',
                      counterText: '',
                      errorText: errorText,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Verify & Activate Account',
                    isLoading: isVerifying,
                    onPressed: () async {
                      final code = codeController.text.trim();
                      if (code.length < 6) {
                        setSheetState(() => errorText = 'Enter the 6-digit verification code');
                        return;
                      }
                      setSheetState(() {
                        isVerifying = true;
                        errorText = null;
                      });
                      try {
                        final res = await Supabase.instance.client.auth.verifyOTP(
                          email: email,
                          token: code,
                          type: OtpType.signup,
                        );
                        if (!mounted) return;
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                        if (res.session != null) {
                          await LoginSuccessDialog.show(this.context, isNewAccount: true);
                          _goToReturnLocation();
                        } else {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('Account verified! You can now log in.')),
                          );
                        }
                      } catch (e) {
                        try {
                          final res2 = await Supabase.instance.client.auth.verifyOTP(
                            email: email,
                            token: code,
                            type: OtpType.email,
                          );
                          if (!mounted) return;
                          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                          if (res2.session != null) {
                            await LoginSuccessDialog.show(this.context, isNewAccount: true);
                            _goToReturnLocation();
                          } else {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('Account verified! You can now log in.')),
                            );
                          }
                        } catch (e2) {
                          setSheetState(() {
                            isVerifying = false;
                            errorText = 'Invalid or expired code. Please try again.';
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Didn't receive the code? ", style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
                      TextButton(
                        onPressed: isResending
                            ? null
                            : () async {
                                setSheetState(() => isResending = true);
                                try {
                                  await Supabase.instance.client.auth.resend(email: email, type: OtpType.signup);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Verification code resent!')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Could not resend: $e')),
                                    );
                                  }
                                } finally {
                                  setSheetState(() => isResending = false);
                                }
                              },
                        child: Text(isResending ? 'Sending...' : 'Resend'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        setState(() {
                          _isLogin = true;
                          _loginEmail.text = email;
                        });
                      },
                      child: const Text('Already verified? Go to Login'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPhoneSignInSheet() {
    final phoneController = TextEditingController(text: '+63');
    final otpController = TextEditingController();
    bool codeSent = false;
    bool isLoading = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                MediaQuery.of(context).viewInsets.bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.colors.ink.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.phone_iphone_rounded, color: context.colors.ink, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              codeSent ? 'Enter SMS Code' : 'Sign in with Phone',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              codeSent
                                  ? 'Enter the 6-digit code sent to ${phoneController.text}'
                                  : 'We will send a 6-digit verification code to your number',
                              style: TextStyle(color: context.colors.textSecondary, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (!codeSent) ...[
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      style: TextStyle(color: context.colors.textPrimary, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '+63 912 345 6789',
                        errorText: errorText,
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    PrimaryButton(
                      label: 'Send Verification Code',
                      isLoading: isLoading,
                      onPressed: () async {
                        final phone = phoneController.text.trim();
                        if (phone.length < 10) {
                          setSheetState(() => errorText = 'Please enter a valid phone number');
                          return;
                        }
                        setSheetState(() {
                          isLoading = true;
                          errorText = null;
                        });
                        try {
                          await Supabase.instance.client.auth.signInWithOtp(phone: phone);
                          setSheetState(() {
                            codeSent = true;
                            isLoading = false;
                          });
                        } catch (e) {
                          setSheetState(() {
                            isLoading = false;
                            errorText = 'Could not send SMS code: $e';
                          });
                        }
                      },
                    ),
                  ] else ...[
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        hintText: '000000',
                        counterText: '',
                        errorText: errorText,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    PrimaryButton(
                      label: 'Verify & Sign In',
                      isLoading: isLoading,
                      onPressed: () async {
                        final otp = otpController.text.trim();
                        if (otp.length < 6) {
                          setSheetState(() => errorText = 'Enter 6-digit code');
                          return;
                        }
                        setSheetState(() {
                          isLoading = true;
                          errorText = null;
                        });
                        try {
                          final res = await Supabase.instance.client.auth.verifyOTP(
                            phone: phoneController.text.trim(),
                            token: otp,
                            type: OtpType.sms,
                          );
                          if (!mounted) return;
                          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                          if (res.session != null) {
                            await LoginSuccessDialog.show(this.context, isNewAccount: false);
                            _goToReturnLocation();
                          }
                        } catch (e) {
                          setSheetState(() {
                            isLoading = false;
                            errorText = 'Invalid or expired code. Please try again.';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => setSheetState(() {
                        codeSent = false;
                        errorText = null;
                      }),
                      child: const Text('Change phone number'),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
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
                Center(child: Image.asset('assets/branding/logo.png', height: 125, semanticLabel: 'BookVerse')),
                const SizedBox(height: 10),
                Text(
                  'BookVerse',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: context.colors.textPrimary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin ? 'Welcome back' : 'Create an Account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _isLogin
                      ? 'Sign in to access your library, cart, and orders'
                      : 'Join BookVerse and explore thousands of books',
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
                        label: 'Phone',
                        isLoading: authState.isLoading,
                        onPressed: _showPhoneSignInSheet,
                        icon: Icon(Icons.phone_iphone_rounded, color: context.colors.textPrimary, size: 20),
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
