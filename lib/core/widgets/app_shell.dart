import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_color_tokens.dart';

/// The persistent bottom-nav scaffold, wired to a
/// `StatefulShellRoute.indexedStack` so each tab keeps its own scroll
/// position/navigation stack when switching away and back. Five tabs —
/// Home / Vouchers / Store / Notifications / Me — with a soft pill
/// highlight behind the active icon. Search (formerly its own tab) now
/// lives as a tappable bar on Home; Library (bookmarks/collections) and
/// order tracking both moved under Me — see home_screen.dart and
/// profile_screen.dart.
class AppShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < _items.length; i++)
                  _NavItem(
                    icon: _items[i].icon,
                    activeIcon: _items[i].activeIcon,
                    label: _items[i].label,
                    selected: navigationShell.currentIndex == i,
                    onTap: () => _goTo(i),
                  ),
              ],
            ),
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
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                  child: Icon(
                    selected ? activeIcon : icon,
                    size: 22,
                    color: selected ? context.colors.ink : context.colors.textTertiary,
                  ),
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
