import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/reading_illustration.dart';

/// The post-auth confirmation from login_basis.png: centered illustration,
/// bold headline, supporting subtext, and a "Got it" pill button. Shown as
/// a full-screen dialog on the root navigator so it appears regardless of
/// where GoRouter's redirect has already sent the underlying route.
class LoginSuccessDialog extends StatelessWidget {
  const LoginSuccessDialog({super.key, required this.isNewAccount});

  final bool isNewAccount;

  static Future<void> show(BuildContext context, {required bool isNewAccount}) {
    HapticFeedback.mediumImpact();
    return showGeneralDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, _) => LoginSuccessDialog(isNewAccount: isNewAccount),
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(animation), child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colors.authBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ReadingIllustration(size: 140, success: true),
            const SizedBox(height: 24),
            Text(
              isNewAccount ? 'Account Created' : 'Login Successful',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Everything looks good, moving you ahead',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 28),
            PrimaryButton(label: 'Got it', onPressed: () => Navigator.of(context, rootNavigator: true).pop()),
          ],
        ),
      ),
    );
  }
}
