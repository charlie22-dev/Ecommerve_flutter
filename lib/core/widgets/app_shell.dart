import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_color_tokens.dart';
import '../../features/notifications/presentation/notification_providers.dart';

/// Emil Kowalski's custom ease-out curve for snappy, intentional UI motion.
const _kEmilEaseOut = Cubic(0.23, 1.0, 0.32, 1.0);

/// The persistent bottom-nav scaffold, wired to a
/// StatefulShellRoute.indexedStack so each tab keeps its own scroll
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

/// A floating, auto-hiding dock designed with Emil Kowalski's UI principles:
/// - Snappy custom ease-out curve (Cubic(0.23, 1, 0.32, 1)).
/// - Tactile scale-on-press feedback (scale(0.95)) on tab items.
/// - Frosted-glass backdrop blur (sigma 18) so scrolling content blurs naturally.
/// - Auto-hides after ~3s of inactivity into a sleek micro-island indicator,
///   maximizing reading space while staying one tap away.
/// - Never animates from scale(0) (always scale(0.95) with opacity and transform).
class _FloatingNavBar extends StatefulWidget {
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
  State<_FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<_FloatingNavBar> {
  bool _isExpanded = true;
  Timer? _idleTimer;

  static const _idleTimeout = Duration(milliseconds: 3000);

  @override
  void initState() {
    super.initState();
    _startIdleTimer();
  }

  @override
  void didUpdateWidget(covariant _FloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _keepActive();
    }
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, () {
      if (mounted && _isExpanded) {
        setState(() => _isExpanded = false);
      }
    });
  }

  void _keepActive() {
    _idleTimer?.cancel();
    if (!_isExpanded) {
      setState(() => _isExpanded = true);
    }
    _startIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 12),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        reverseDuration: const Duration(milliseconds: 200),
        switchInCurve: _kEmilEaseOut,
        switchOutCurve: _kEmilEaseOut,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              // Never animate from 0: scale in from 0.94
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: _isExpanded
            ? _buildFullDock(context, colors)
            : _buildCollapsedIsland(context, colors),
      ),
    );
  }

  Widget _buildFullDock(BuildContext context, AppColorTokens colors) {
    return ClipRRect(
      key: const ValueKey('full_dock'),
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: colors.border.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 28,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
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
                for (var i = 0; i < widget.items.length; i++)
                  _NavItem(
                    icon: widget.items[i].icon,
                    activeIcon: widget.items[i].activeIcon,
                    label: widget.items[i].label,
                    selected: widget.currentIndex == i,
                    onTap: () {
                      _keepActive();
                      widget.onTap(i);
                    },
                    badgeCount: i == 3 ? widget.unreadCount : 0,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedIsland(BuildContext context, AppColorTokens colors) {
    final activeItem = widget.items[widget.currentIndex];

    return Center(
      key: const ValueKey('collapsed_island'),
      child: _PressableScale(
        onTap: _keepActive,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.border.withValues(alpha: 0.7)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(activeItem.activeIcon, size: 20, color: colors.ink),
                  const SizedBox(width: 8),
                  Text(
                    activeItem.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (widget.unreadCount > 0 && widget.currentIndex != 3) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        widget.unreadCount > 99 ? '99+' : '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.unfold_more_rounded, size: 16, color: colors.textTertiary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tactile pressable container that scales to 0.95 on active press,
/// giving instant responsive feedback (Emil Kowalski button principle).
class _PressableScale extends StatefulWidget {
  const _PressableScale({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _kEmilEaseOut,
        child: widget.child,
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
    final colors = context.colors;
    final iconWidget = Icon(
      selected ? activeIcon : icon,
      size: 22,
      color: selected ? colors.ink : colors.textTertiary,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: _PressableScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 50, minHeight: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: _kEmilEaseOut,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? colors.surfaceMuted : Colors.transparent,
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
                                  badgeCount > 99 ? '99+' : '',
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
                    color: selected ? colors.ink : colors.textTertiary,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    letterSpacing: -0.1,
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
