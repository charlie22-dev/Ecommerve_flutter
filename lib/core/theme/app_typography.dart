import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A single clean geometric-sans family (Figtree) at varying weights for
/// both display and body text — matches login_basis.png / main_basis.png's
/// friendly, uniform ecommerce typography (no condensed/comic display face).
abstract final class AppTypography {
  static TextTheme textTheme(TextTheme base, {required Color textColor}) {
    final body = GoogleFonts.figtreeTextTheme(base);

    return body
        .copyWith(
          displayLarge: body.displayLarge?.copyWith(fontWeight: FontWeight.w800),
          displayMedium: body.displayMedium?.copyWith(fontWeight: FontWeight.w800),
          displaySmall: body.displaySmall?.copyWith(fontWeight: FontWeight.w800),
          headlineLarge: body.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
          headlineMedium: body.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          headlineSmall: body.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          titleLarge: body.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          titleSmall: body.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          labelMedium: body.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          labelSmall: body.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(
          bodyColor: textColor,
          displayColor: textColor,
        );
  }
}
