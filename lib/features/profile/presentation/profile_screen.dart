import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/require_login.dart';
import '../../../core/dev/dev_preview.dart';
import '../../../core/models/library_entry.dart';
import '../../../core/models/reader_badge.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/cart_icon_button.dart';
import '../../../core/widgets/primary_button.dart';
import '../../admin/presentation/admin_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../checkout/presentation/orders_screen.dart';
import '../../library/presentation/library_providers.dart';
import '../../seller/presentation/seller_providers.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../wishlist/presentation/wishlist_providers.dart';
import 'widgets/profile_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Me is guest-accessible now (see app_router.dart) — a guest sees a
    // "Sign In" prompt instead of the full profile rather than being
    // redirected away, same as Shopee/Lazada's Me tab. Checked against
    // `authStateProvider` (the auth session's user), not `appUserProvider`,
    // since the latter is also transiently null for a real signed-in user
    // whose `profiles` row just hasn't loaded yet.
    final isLoggedIn = ref.watch(authStateProvider).value != null || ref.watch(devGuestModeProvider);
    if (!isLoggedIn) {
      return const _GuestMeScreen();
    }

    final appUser = ref.watch(appUserProvider).value;
    final isAdmin = ref.watch(isAdminProvider);
    final hasStore = ref.watch(myStoreProvider).value != null;
    final currentlyReading =
        ref.watch(shelfEntriesProvider(ReadingShelf.currentlyReading)).value?.length ?? 0;
    final savedCount = ref.watch(wishlistIdsProvider).value?.length ?? 0;

    final badges = ReaderBadge.compute(
      booksCompletedCount: appUser?.booksCompletedCount ?? 0,
      streakCount: appUser?.streakCount ?? 0,
      longestStreak: appUser?.longestStreak ?? 0,
    );

    // SingleChildScrollView (not a fixed Column) so content taller than the
    // viewport — long badge lists, large Dynamic Type scales — scrolls
    // instead of overflowing.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Me'),
        actions: [
          const CartIconButton(),
          Semantics(
            button: true,
            label: 'Messages',
            child: IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              onPressed: () => context.push('/messages'),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    ProfileAvatar(photoUrl: appUser?.photoUrl, radius: 42),
                    const SizedBox(height: 12),
                    Text(
                      appUser?.displayName.isEmpty ?? true ? 'Reader' : appUser!.displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appUser?.email ?? '',
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 180,
                      child: PrimaryButton(
                        label: 'Edit Profile',
                        onPressed: () => context.push(AppRoute.editProfile),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  _StatCard(
                    icon: Icons.local_fire_department_rounded,
                    value: '${appUser?.streakCount ?? 0}',
                    label: 'Day streak',
                    color: context.colors.ink,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.menu_book_rounded,
                    value: '${appUser?.booksCompletedCount ?? 0}',
                    label: 'Completed',
                    color: context.colors.success,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.auto_stories_rounded,
                    value: '$currentlyReading',
                    label: 'Reading',
                    color: context.colors.info,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('My Orders', style: Theme.of(context).textTheme.titleMedium),
                  Semantics(
                    button: true,
                    label: 'See all orders',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => context.push('/orders'),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Text('See All', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _OrderStatusIcon(icon: Icons.payments_outlined, label: 'To Pay', tab: OrderTab.toPay),
                  _OrderStatusIcon(icon: Icons.inventory_2_outlined, label: 'To Ship', tab: OrderTab.toShip),
                  _OrderStatusIcon(icon: Icons.local_shipping_outlined, label: 'To Receive', tab: OrderTab.toReceive),
                  _OrderStatusIcon(icon: Icons.star_outline_rounded, label: 'To Rate', tab: OrderTab.toRate),
                ],
              ),
              const SizedBox(height: 28),
              Text('Badges', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              // Wrap (not a GridView with a fixed aspect ratio) — badge
              // tiles size to their own content, so a longer title or a
              // larger Dynamic Type scale reflows instead of overflowing
              // a height Flutter computed from the grid's aspect ratio.
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: badges.map((badge) => _BadgeTile(badge: badge)).toList(),
              ),
              const SizedBox(height: 28),
              Text('Library', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Divider(height: 1, color: context.colors.borderSubtle),
              _ProfileListRow(
                icon: Icons.bookmark_border_rounded,
                label: 'Saved Books',
                trailingText: '$savedCount',
                onTap: () => context.push(AppRoute.library),
              ),
              Divider(height: 1, color: context.colors.borderSubtle),
              _ProfileListRow(
                icon: Icons.storefront_outlined,
                label: hasStore ? 'Seller Center' : 'Become a Seller',
                onTap: () => context.push(AppRoute.seller),
              ),
              Divider(height: 1, color: context.colors.borderSubtle),
              if (isAdmin) ...[
                _ProfileListRow(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Admin Panel',
                  onTap: () => context.push(AppRoute.admin),
                ),
                Divider(height: 1, color: context.colors.borderSubtle),
              ],
              _ProfileListRow(
                icon: Icons.logout_rounded,
                label: 'Sign out',
                iconColor: context.colors.error,
                labelColor: context.colors.error,
                onTap: () {
                  ref.read(devGuestModeProvider.notifier).state = false;
                  ref.read(authControllerProvider.notifier).signOut();
                },
              ),
              Divider(height: 1, color: context.colors.borderSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestMeScreen extends ConsumerWidget {
  const _GuestMeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Me'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(color: colors.surfaceMuted, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(Icons.person_rounded, size: 42, color: colors.textTertiary),
              ),
              const SizedBox(height: 20),
              Text('Welcome to BookVerse', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                'Sign in to see your orders, saved books, badges, and more.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: PrimaryButton(label: 'Sign In', onPressed: () => goToLogin(context, ref)),
              ),
              const SizedBox(height: 32),
              Divider(height: 1, color: colors.borderSubtle),
              _ProfileListRow(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
              Divider(height: 1, color: colors.borderSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label, required this.color});
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(color: context.colors.textTertiary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderStatusIcon extends StatelessWidget {
  const _OrderStatusIcon({required this.icon, required this.label, required this.tab});
  final IconData icon;
  final String label;
  final OrderTab tab;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/orders', extra: tab),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: colors.textPrimary, size: 24),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary, fontSize: 11.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});
  final ReaderBadge badge;

  @override
  Widget build(BuildContext context) {
    final earned = badge.isEarned;
    return Opacity(
      opacity: earned ? 1 : 0.4,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: earned ? context.colors.ink : context.colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badge.icon, color: earned ? context.colors.ink : context.colors.textTertiary, size: 26),
            const SizedBox(height: 6),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.colors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileListRow extends StatelessWidget {
  const _ProfileListRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingText,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailingText;

  /// Both default to the theme's `textPrimary` token — kept nullable since
  /// a constructor default must be a compile-time constant.
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: trailingText != null ? '$label, $trailingText' : label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                Icon(icon, size: 22, color: iconColor ?? colors.textPrimary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(label, style: TextStyle(color: labelColor ?? colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                if (trailingText != null) ...[
                  Text(trailingText!, style: TextStyle(color: colors.textTertiary, fontSize: 13)),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.chevron_right_rounded, color: colors.textTertiary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
