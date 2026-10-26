import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/pending_return_location.dart';
import '../../../core/dev/dev_preview.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../auth/presentation/auth_controller.dart';
import 'admin_providers.dart';

/// Wraps every /admin page. On wide screens (web/desktop) it adds a fixed
/// sidebar like Shopee Seller Centre or Shopify Admin; on phones it adds
/// nothing and the dashboard's own menu does the navigating.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const wideBreakpoint = 900.0;

  static bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= wideBreakpoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isWide(context)) return child;
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: Row(
        children: [
          _Sidebar(location: location),
          VerticalDivider(width: 1, thickness: 1, color: colors.border),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.location});
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final todo = ref.watch(adminTodoProvider);

    bool under(String route) => location == route || location.startsWith('$route/');

    final items = <_Item>[
      _Item(Icons.space_dashboard_outlined, 'Dashboard', AppRoute.admin, selected: location == AppRoute.admin),
      _Item(Icons.receipt_long_outlined, 'Orders', AppRoute.adminOrders,
          badge: todo.toShip, selected: under(AppRoute.adminOrders)),
      _Item(Icons.menu_book_outlined, 'Products', AppRoute.adminProducts,
          selected: under(AppRoute.adminProducts) || under(AppRoute.adminAddProduct)),
      _Item(Icons.fact_check_outlined, 'Listing review', AppRoute.adminListings,
          badge: todo.listingsToReview, selected: under(AppRoute.adminListings)),
      _Item(Icons.storefront_outlined, 'Sellers', AppRoute.adminSellers,
          badge: todo.sellerApplications, selected: under(AppRoute.adminSellers)),
      _Item(Icons.confirmation_number_outlined, 'Vouchers', AppRoute.adminVouchers,
          selected: under(AppRoute.adminVouchers)),
      _Item(Icons.chat_bubble_outline_rounded, 'Messages', AppRoute.adminMessages,
          badge: todo.unansweredMessages, selected: under(AppRoute.adminMessages)),
    ];

    return Container(
      width: 240,
      color: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  Image.asset('assets/branding/mark.png', height: 36),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BookVerse', style: Theme.of(context).textTheme.titleLarge),
                      Text('Admin Panel', style: TextStyle(color: colors.textTertiary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [for (final item in items) _SidebarTile(item: item)],
              ),
            ),
            Divider(height: 1, color: colors.borderSubtle),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _SidebarTile(
                    item: _Item(Icons.arrow_back_rounded, 'Back to store', AppRoute.profile, selected: false),
                  ),
                  _SidebarTile(
                    item: _Item(Icons.logout_rounded, 'Sign out', '', selected: false),
                    customColor: colors.error,
                    onCustomTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Sign out?'),
                          content: const Text('Are you sure you want to sign out of BookVerse Admin?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: Text('Sign out', style: TextStyle(color: ctx.colors.error)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        ref.read(pendingReturnLocationProvider.notifier).state = null;
                        ref.read(devGuestModeProvider.notifier).state = false;
                        await ref.read(authControllerProvider.notifier).signOut();
                        if (context.mounted) {
                          context.go(AppRoute.home);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item {
  const _Item(this.icon, this.label, this.route, {required this.selected, this.badge = 0});
  final IconData icon;
  final String label;
  final String route;
  final bool selected;
  final int badge;
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.item, this.onCustomTap, this.customColor});
  final _Item item;
  final VoidCallback? onCustomTap;
  final Color? customColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = customColor ?? (item.selected ? colors.onInk : colors.textPrimary);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: item.selected ? colors.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          // `go`, not `push`: sections replace each other, like tabs.
          onTap: onCustomTap ?? () => context.go(item.route),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                if (item.badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: colors.error, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '${item.badge}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
