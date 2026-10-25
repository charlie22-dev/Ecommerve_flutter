import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Emil Kowalski / Apple-style fluid deceleration curve for natural, snappy motion.
const _kFluidEaseOut = Cubic(0.22, 1.0, 0.36, 1.0);
const _kFluidEaseIn = Cubic(0.4, 0.0, 0.7, 0.2);

/// Highly optimized page transition helper for GoRouter.
///
/// Uses subtle offset translation + fade transition with GPU-accelerated
/// transforms, avoiding large viewport re-layout hitches.
CustomTransitionPage<void> buildSmoothPage({
  required GoRouterState state,
  required Widget child,
  bool slideFromBottom = false,
  Duration duration = const Duration(milliseconds: 260),
  Duration reverseDuration = const Duration(milliseconds: 220),
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: _kFluidEaseOut,
        reverseCurve: _kFluidEaseIn,
      );

      final curvedSecondary = CurvedAnimation(
        parent: secondaryAnimation,
        curve: _kFluidEaseOut,
        reverseCurve: _kFluidEaseIn,
      );

      // Primary entrance: subtle slide + opacity fade
      final slideIn = Tween<Offset>(
        begin: slideFromBottom ? const Offset(0.0, 0.08) : const Offset(0.10, 0.0),
        end: Offset.zero,
      ).animate(curvedAnimation);

      final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);

      // Secondary exit (when another page pushes on top): slight parallax slide back
      final slideOut = Tween<Offset>(
        begin: Offset.zero,
        end: slideFromBottom ? const Offset(0.0, -0.04) : const Offset(-0.04, 0.0),
      ).animate(curvedSecondary);

      final fadeOut = Tween<double>(begin: 1.0, end: 0.88).animate(curvedSecondary);

      return SlideTransition(
        position: slideOut,
        child: FadeTransition(
          opacity: fadeOut,
          child: SlideTransition(
            position: slideIn,
            child: FadeTransition(
              opacity: fadeIn,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
