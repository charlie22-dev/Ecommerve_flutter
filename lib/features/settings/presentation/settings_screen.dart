import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_color_tokens.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/presentation/profile_edit_controller.dart';
import 'language_settings_screen.dart';
import 'simple_content_screen.dart';

/// Real, working settings only — no toggle ships here without something
/// behind it (see the dark-mode scope discussion: this is the full,
/// app-wide version, not a decorative switch).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.dark;
    final isDeleting = ref.watch(profileEditControllerProvider).isLoading;

    ref.listen(profileEditControllerProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error.toString()), backgroundColor: colors.error),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionLabel('Appearance'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: SwitchListTile(
              value: themeMode == ThemeMode.dark,
              onChanged: (value) => ref.read(themeModeProvider.notifier).setThemeMode(
                    value ? ThemeMode.dark : ThemeMode.light,
                  ),
              title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
              activeThumbColor: colors.ink,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Shopping'),
          _SettingsInfoRow(icon: Icons.payments_outlined, label: 'Currency', value: 'PHP (₱)'),
          const SizedBox(height: 24),
          _SectionLabel('General'),
          _SettingsRow(
            icon: Icons.language_rounded,
            label: 'Language Settings',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LanguageSettingsScreen())),
          ),
          const Divider(height: 1),
          _SettingsRow(
            icon: Icons.help_outline_rounded,
            label: 'Help Center',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _HelpCenterScreen())),
          ),
          const Divider(height: 1),
          _SettingsRow(
            icon: Icons.groups_outlined,
            label: 'Community Rules',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _CommunityRulesScreen())),
          ),
          const Divider(height: 1),
          _SettingsRow(
            icon: Icons.gavel_outlined,
            label: 'Policies',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _PoliciesScreen())),
          ),
          const Divider(height: 1),
          _SettingsRow(
            icon: Icons.star_outline_rounded,
            label: 'Rate Us',
            onTap: () => _showRateUsDialog(context),
          ),
          const Divider(height: 1),
          _SettingsRow(
            icon: Icons.info_outline_rounded,
            label: 'About Us',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _AboutUsScreen())),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Account'),
          _SettingsRow(
            icon: Icons.delete_outline_rounded,
            label: 'Delete Account',
            labelColor: colors.error,
            iconColor: colors.error,
            isLoading: isDeleting,
            onTap: () => _confirmDeleteAccount(context, ref),
          ),
          const SizedBox(height: 24),
          _SectionLabel('About'),
          const _SettingsInfoRow(icon: Icons.info_outline_rounded, label: 'BookVerse', value: 'v1.0.0'),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          "This permanently deletes your account and profile. Your library, wishlist, and order history won't be recoverable. This can't be undone.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await ref.read(profileEditControllerProvider.notifier).deleteAccount();
    if (ok) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  // BookVerse isn't published on an app store yet, so there's no real
  // store listing to deep-link to — this stays an honest in-app thank-you
  // instead of launching a URL that doesn't exist.
  Future<void> _showRateUsDialog(BuildContext context) {
    final colors = context.colors;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.star_rounded, color: colors.star, size: 36),
        title: const Text('Enjoying BookVerse?'),
        content: const Text(
          "Thanks for using BookVerse! Store ratings will open here once the app is published.",
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _HelpCenterScreen extends StatelessWidget {
  const _HelpCenterScreen();

  @override
  Widget build(BuildContext context) {
    return const SimpleContentScreen(
      title: 'Help Center',
      sections: [
        ContentSection('Placing an order', 'Add books to your cart from any product page, then tap Checkout. Choose a shipping address, shipping option, and payment method — Cash on Delivery is always available.'),
        ContentSection('Tracking an order', 'Open Me → My Orders to see everything currently To Pay, To Ship, To Receive, or To Rate. Tap any order for full details.'),
        ContentSection('Using a voucher', 'Apply a voucher code at checkout, or browse active vouchers from the Vouchers tab.'),
        ContentSection('Payment methods', 'Cash on Delivery is fully supported. GCash, Maya, and Card are available at checkout but require a connected payment provider to complete.'),
        ContentSection('Still need help?', 'Message BookVerse Store directly from Me → Messages, or Notifications → Messages.'),
      ],
    );
  }
}

class _CommunityRulesScreen extends StatelessWidget {
  const _CommunityRulesScreen();

  @override
  Widget build(BuildContext context) {
    return const SimpleContentScreen(
      title: 'Community Rules',
      sections: [
        ContentSection('Be respectful', 'Reviews and messages should stay civil — no harassment, hate speech, or spam.'),
        ContentSection('Review honestly', 'Only rate and review books from orders you\'ve actually received. Fake or paid reviews may be removed.'),
        ContentSection('No prohibited content', 'Don\'t use messages or reviews to share content unrelated to books or that violates local law.'),
        ContentSection('Report issues', 'If you see content that breaks these rules, message BookVerse Store to report it.'),
      ],
    );
  }
}

class _PoliciesScreen extends StatelessWidget {
  const _PoliciesScreen();

  @override
  Widget build(BuildContext context) {
    return const SimpleContentScreen(
      title: 'Policies',
      sections: [
        ContentSection('Privacy', 'BookVerse stores your account details, orders, and reading activity to run the app. Your data is stored securely on our Supabase-hosted servers and is only accessible to your account.'),
        ContentSection('Orders & payments', 'Orders paid via Cash on Delivery are confirmed immediately. Other payment methods require a connected payment provider before they can complete.'),
        ContentSection('Returns', 'Contact BookVerse Store within 7 days of delivery for return or replacement requests on damaged items.'),
        ContentSection('Account deletion', 'You can permanently delete your account and data anytime from Settings → Delete Account.'),
      ],
    );
  }
}

class _AboutUsScreen extends StatelessWidget {
  const _AboutUsScreen();

  @override
  Widget build(BuildContext context) {
    return const SimpleContentScreen(
      title: 'About Us',
      sections: [
        ContentSection('BookVerse', 'A marketplace and reading tracker for manga, manhwa, manhua, comics, and light novels — built for readers who want to shop and track their shelf in one place.'),
        ContentSection('Version', 'v1.0.0 — in active development.'),
        ContentSection('Our mission', 'Make it easy to discover, buy, and keep track of the books you\'re reading and collecting.'),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: TextStyle(color: context.colors.textTertiary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.iconColor,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;
  final Color? iconColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.border)),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                Icon(icon, size: 22, color: iconColor ?? colors.textPrimary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(label, style: TextStyle(color: labelColor ?? colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                if (isLoading)
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: colors.error))
                else
                  Icon(Icons.chevron_right_rounded, color: colors.textTertiary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  const _SettingsInfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: colors.textPrimary),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600))),
          Text(value, style: TextStyle(color: colors.textTertiary, fontSize: 13)),
        ],
      ),
    );
  }
}
