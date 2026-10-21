import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_color_tokens.dart';
import '../../features/notifications/presentation/notification_providers.dart';

/// Emil Kowalski's custom ease-out curve for snappy, intentional UI motion.
const _kEmilEaseOut = Cubic(0.23, 1.0, 0.32, 1.0);

/// The persistent bottom-nav scaffold, wired to a
/// StatefulShellRoute.indexedStack so each tab keeps its own scroll
/// position/navigation stack when switching away and back.
///
/// Features scroll-to-hide behavior: when scrolling or swiping down, the nav
/// smoothly slides off the bottom of the screen. When scrolling up or when
/// scrolling stops, it springs back into view.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _isNavVisible = true;
  Timer? _stopScrollTimer;

  static const _items = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.local_offer_outlined, activeIcon: Icons.local_offer_rounded, label: 'Vouchers'),
    (icon: Icons.storefront_outlined, activeIcon: Icons.storefront_rounded, label: 'Store'),
    (icon: Icons.notifications_outlined, activeIcon: Icons.notifications_rounded, label: 'Notifications'),
    (icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Me'),
  ];

  /// From this width up the tabs move to a website-style top bar.
  static const wideBreakpoint = 900.0;

  void _goTo(int i) {
    if (!_isNavVisible) {
      setState(() => _isNavVisible = true);
    }
    widget.navigationShell.goBranch(i, initialLocation: i == widget.navigationShell.currentIndex);
  }

  void _onUserScroll(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse) {
      // User is scrolling down: smoothly hide nav into the bottom
      if (_isNavVisible) {
        setState(() => _isNavVisible = false);
      }
      _stopScrollTimer?.cancel();
      // Auto-restore after user stops scrolling for 1.2s
      _stopScrollTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted && !_isNavVisible) {
          setState(() => _isNavVisible = true);
        }
      });
    } else if (notification.direction == ScrollDirection.forward) {
      // User is scrolling up: bring nav back immediately
      if (!_isNavVisible) {
        setState(() => _isNavVisible = true);
      }
      _stopScrollTimer?.cancel();
    } else if (notification.direction == ScrollDirection.idle) {
      // User stopped scrolling: restore nav smoothly
      _stopScrollTimer?.cancel();
      _stopScrollTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted && !_isNavVisible) {
          setState(() => _isNavVisible = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _stopScrollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    if (MediaQuery.sizeOf(context).width >= wideBreakpoint) {
      return Scaffold(
        body: Column(
          children: [
            _TopBar(items: _items, currentIndex: widget.navigationShell.currentIndex, onTap: _goTo),
            Expanded(child: widget.navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          _onUserScroll(notification);
          return false;
        },
        child: widget.navigationShell,
      ),
      bottomNavigationBar: AnimatedSlide(
        offset: _isNavVisible ? Offset.zero : const Offset(0, 1.5),
        duration: const Duration(milliseconds: 240),
        curve: _kEmilEaseOut,
        child: AnimatedOpacity(
          opacity: _isNavVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          curve: _kEmilEaseOut,
          child: _FloatingNavBar(
            items: _items,
            currentIndex: widget.navigationShell.currentIndex,
            onTap: _goTo,
            unreadCount: unreadCount,
          ),
        ),
      ),
    );
  }
}

/// The floating dock: sits above the bottom safe area, fully rounded pill,
/// with frosted-glass blur so content softly blurs behind it.
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
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 12),
      child: ClipRRect(
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
