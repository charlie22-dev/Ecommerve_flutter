import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_color_tokens.dart';
import '../../features/notifications/presentation/notification_providers.dart';

/// The persistent bottom-nav scaffold, wired to a
/// `StatefulShellRoute.indexedStack` so each tab keeps its own scroll
/// position/navigation stack when switching away and back. Five tabs —
/// Home / Vouchers / Store / Notifications / Me — with a soft pill
/// highlight behind the active icon. Search (formerly its own tab) now
/// lives as a tappable bar on Home; Library (bookmarks/collections) and
/// order tracking both moved under Me — see home_screen.dart and
/// profile_screen.dart.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.local_offer_outlined, activeIcon: Icons.local_offer_rounded, label: 'Vouchers'),
    (icon: Icons.storefront_outlined, activeIcon: Icons.storefront_rounded, label: 'Store'),
    (icon: Icons.notifications_outlined, activeIcon: Icons.notifications_rounded, label: 'Notifications'),
    (icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Me'),
  ];

  /// From this width up the tabs move to a website-style top bar.
  static const wideBreakpoint = 900.0;

  void _goTo(int i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    if (MediaQuery.sizeOf(context).width >= wideBreakpoint) {
      return Scaffold(
        body: Column(
          children: [
            _TopBar(items: _items, currentIndex: navigationShell.currentIndex, onTap: _goTo),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }
    // extendBody lets the page content render behind the floating nav so it
    // can scroll all the way to the bottom of the screen.
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _FloatingNavBar(
        items: _items,
        currentIndex: navigationShell.currentIndex,
        onTap: _goTo,
        unreadCount: unreadCount,
      ),
    );
  }
}

/// The floating pill nav bar shown on mobile. It sits 16 px above the device's
/// bottom safe-area edge, is inset 16 px from each side, fully rounded, and
/// casts a soft shadow — giving the "floating" look without any third-party
/// packages. `Scaffold(extendBody: true)` lets page content scroll beneath it.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.unreadCount,
  });

  final List<({IconData icon, IconData activeIcon, String label})> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      // Sit above the home indicator / nav bar, inset 16 px each side with top margin for floating effect.
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < items.length; i++)
                _NavItem(
                  icon: items[i].icon,
                  activeIcon: items[i].activeIcon,
                  label: items[i].label,
                  selected: currentIndex == i,
                  onTap: () => onTap(i),
                  badgeCount: i == 3 ? unreadCount : 0,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desktop/web header: logo on the left, the same five sections as links.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.items, required this.currentIndex, required this.onTap});

  final List<({IconData icon, IconData activeIcon, String label})> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border))),
      child: Row(
        children: [
          InkWell(
            onTap: () => onTap(0),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  Image.asset('assets/branding/mark.png', height: 34, semanticLabel: 'BookVerse home'),
                  const SizedBox(width: 10),
                  Text('BookVerse', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
          ),
          const Spacer(),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Semantics(
                button: true,
                selected: currentIndex == i,
                child: TextButton.icon(
                  onPressed: () => onTap(i),
                  style: TextButton.styleFrom(
                    backgroundColor: currentIndex == i ? colors.surfaceMuted : Colors.transparent,
                    foregroundColor: currentIndex == i ? colors.ink : colors.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                  icon: Icon(currentIndex == i ? items[i].activeIcon : items[i].icon, size: 20),
                  label: Text(
                    items[i].label,
                    style: TextStyle(fontWeight: currentIndex == i ? FontWeight.w800 : FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Number to show in the red badge bubble. 0 = no badge.
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      selected ? activeIcon : icon,
      size: 22,
      color: selected ? context.colors.ink : context.colors.textTertiary,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? context.colors.surfaceMuted : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: badgeCount > 0
                      ? Stack(
                          clipBehavior: Clip.none,
                          children: [
                            iconWidget,
                            Positioned(
                              right: -6,
                              top: -6,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  badgeCount > 99 ? '99+' : '$badgeCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : iconWidget,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected ? context.colors.ink : context.colors.textTertiary,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
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
