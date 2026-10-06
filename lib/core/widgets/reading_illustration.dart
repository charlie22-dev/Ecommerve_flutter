import 'package:flutter/material.dart';

import '../theme/app_color_tokens.dart';

/// A simple book-themed hero illustration for the auth screen, standing in
/// for login_basis.png's shield-and-lock mascot — built from layered
/// shapes/icons rather than a bitmap asset, so it's crisp at any size and
/// needs no image file to ship.
class ReadingIllustration extends StatelessWidget {
  const ReadingIllustration({super.key, this.size = 180, this.success = false});

  final double size;

  /// Swaps the open-book badge for a checkmark — used on the post-auth
  /// success screen so the same illustration language carries through.
  final bool success;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.78,
            height: size * 0.78,
            decoration: BoxDecoration(color: context.colors.accentBlueMuted, shape: BoxShape.circle),
          ),
          Positioned(
            top: size * 0.06,
            left: size * 0.02,
            child: Icon(Icons.auto_awesome_rounded, color: context.colors.accentBlue, size: size * 0.14),
          ),
          Positioned(
            bottom: size * 0.1,
            right: size * 0.04,
            child: Icon(Icons.auto_awesome_rounded, color: context.colors.accentBlue.withValues(alpha: 0.6), size: size * 0.1),
          ),
          Container(
            width: size * 0.56,
            height: size * 0.56,
            decoration: BoxDecoration(
              color: context.colors.accentBlue,
              borderRadius: BorderRadius.circular(size * 0.16),
              boxShadow: [
                BoxShadow(color: context.colors.accentBlue.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 12)),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(Icons.menu_book_rounded, color: Colors.white, size: size * 0.3),
          ),
          Positioned(
            top: size * 0.02,
            right: size * 0.06,
            child: Container(
              width: size * 0.24,
              height: size * 0.24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: context.colors.accentBlue, width: 2),
              ),
              alignment: Alignment.center,
              child: Icon(
                success ? Icons.check_rounded : Icons.star_rounded,
                color: success ? context.colors.success : context.colors.star,
                size: size * 0.14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
