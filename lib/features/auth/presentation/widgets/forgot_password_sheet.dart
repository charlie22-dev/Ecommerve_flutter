import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/widgets/primary_button.dart';
import '../auth_controller.dart';
import '../auth_validators.dart';

/// A dedicated Forgot Password flow — its own form/state, not piggybacked
/// on whatever's currently typed into the Login email field, so it works
/// correctly regardless of which mode the auth screen is in.
class ForgotPasswordSheet extends ConsumerStatefulWidget {
  const ForgotPasswordSheet({super.key, this.initialEmail});

  final String? initialEmail;

  static Future<void> show(BuildContext context, {String? initialEmail}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ForgotPasswordSheet(initialEmail: initialEmail),
    );
  }

  @override
  ConsumerState<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    final ok = await ref.read(authControllerProvider.notifier).sendPasswordReset(_email.text);

    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = ok;
    });

    if (!ok) {
      final error = ref.read(authControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error?.toString() ?? 'Could not send reset email.'),
          backgroundColor: context.colors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: _sent ? _buildSentState(colors) : _buildFormState(colors),
        ),
      ),
    );
  }

  Widget _buildFormState(AppColorTokens colors) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(4)),
          ),
          Text('Reset your password', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            "Enter the email on your account and we'll send you a link to reset your password.",
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: colors.textPrimary),
            decoration: const InputDecoration(hintText: 'you@example.com'),
            validator: AuthValidators.email,
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: 'Send reset link', isLoading: _sending, onPressed: _submit),
        ],
      ),
    );
  }

  Widget _buildSentState(AppColorTokens colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: colors.successMuted, shape: BoxShape.circle),
          child: Icon(Icons.mark_email_read_rounded, color: colors.success, size: 32),
        ),
        const SizedBox(height: 16),
        Text('Check your email', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'If an account exists for "${_email.text.trim()}", a password reset link is on its way.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),
        PrimaryButton(label: 'Done', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
