import 'package:flutter/material.dart';

/// Semantic color roles, resolved per-theme via `Theme.of(context)` so the
/// whole app re-skins when [ThemeMode] flips — see `context.colors` below.
/// `app_theme.dart` builds the light/dark `ThemeData` from [light]/[dark];
/// no other file should reference these color literals directly.
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  const AppColorTokens({
    required this.background,
    required this.authBackground,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.borderSubtle,
    required this.ink,
    required this.onInk,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accentBlue,
    required this.accentBlueMuted,
    required this.accentOrange,
    required this.onAccentOrange,
    required this.star,
    required this.success,
    required this.successMuted,
    required this.error,
    required this.info,
    required this.overlay,
    required this.shelfCurrentlyReading,
    required this.shelfCompleted,
    required this.shelfWantToRead,
    required this.shelfFavorites,
  });

  final Color background;
  final Color authBackground;

  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color borderSubtle;

  /// The "solid pill button" color — near-black on light, near-white on
  /// dark. Content drawn ON TOP of an `ink`-colored surface (button
  /// labels, selected-chip text, badge glyphs) must use [onInk], not a
  /// hardcoded `Colors.white`, or it goes invisible when this flips.
  final Color ink;
  final Color onInk;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  final Color accentBlue;
  final Color accentBlueMuted;

  /// The "Buy Now" CTA color — a fixed brand orange, not theme-derived like
  /// [ink], so the button reads the same urgent orange in both themes.
  final Color accentOrange;
  final Color onAccentOrange;

  final Color star;

  final Color success;
  final Color successMuted;
  final Color error;
  final Color info;

  final Color overlay;

  final Color shelfCurrentlyReading;
  final Color shelfCompleted;
  final Color shelfWantToRead;
  final Color shelfFavorites;

  static const light = AppColorTokens(
    background: Color(0xFFF2F1ED),
    authBackground: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEAE8E1),
    border: Color(0xFFE3E1D9),
    borderSubtle: Color(0xFFEDEBE4),
    ink: Color(0xFF16160F),
    onInk: Colors.white,
    textPrimary: Color(0xFF16160F),
    textSecondary: Color(0xFF75746C),
    textTertiary: Color(0xFFA2A099),
    accentBlue: Color(0xFF4A90E2),
    accentBlueMuted: Color(0xFFDCEAFB),
    accentOrange: Color(0xFFFF7A1A),
    onAccentOrange: Colors.white,
    star: Color(0xFFFFB800),
    success: Color(0xFF34A853),
    successMuted: Color(0xFFE1F4E6),
    error: Color(0xFFE5484D),
    info: Color(0xFF4A90E2),
    overlay: Color(0x991A1A14),
    shelfCurrentlyReading: Color(0xFF4A90E2),
    shelfCompleted: Color(0xFF34A853),
    shelfWantToRead: Color(0xFF9C6ADE),
    shelfFavorites: Color(0xFFE5484D),
  );

  // A genuinely dark theme — true neutral near-black, not the warm
  // brown/olive-tinted "dark" of an earlier pass. Every gray here is
  // desaturated (equal-ish RGB), so surfaces read as black/charcoal
  // instead of espresso.
  static const dark = AppColorTokens(
    background: Color(0xFF000000),
    authBackground: Color(0xFF000000),
    surface: Color(0xFF121212),
    surfaceMuted: Color(0xFF1C1C1C),
    border: Color(0xFF2C2C2C),
    borderSubtle: Color(0xFF1C1C1C),
    ink: Color(0xFFF5F5F5),
    onInk: Color(0xFF000000),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFA3A3A3),
    textTertiary: Color(0xFF737373),
    accentBlue: Color(0xFF6BA6F0),
    accentBlueMuted: Color(0xFF17222E),
    accentOrange: Color(0xFFFF8A3D),
    onAccentOrange: Colors.black,
    star: Color(0xFFFFC22E),
    success: Color(0xFF3FD97B),
    successMuted: Color(0xFF13291B),
    error: Color(0xFFFF6B6B),
    info: Color(0xFF6BA6F0),
    overlay: Color(0xE6000000),
    shelfCurrentlyReading: Color(0xFF6BA6F0),
    shelfCompleted: Color(0xFF3FD97B),
    shelfWantToRead: Color(0xFFB58EEA),
    shelfFavorites: Color(0xFFFF6B6B),
  );

  @override
  AppColorTokens copyWith({
    Color? background,
    Color? authBackground,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? borderSubtle,
    Color? ink,
    Color? onInk,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accentBlue,
    Color? accentBlueMuted,
    Color? accentOrange,
    Color? onAccentOrange,
    Color? star,
    Color? success,
    Color? successMuted,
    Color? error,
    Color? info,
    Color? overlay,
    Color? shelfCurrentlyReading,
    Color? shelfCompleted,
    Color? shelfWantToRead,
    Color? shelfFavorites,
  }) {
    return AppColorTokens(
      background: background ?? this.background,
      authBackground: authBackground ?? this.authBackground,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      ink: ink ?? this.ink,
      onInk: onInk ?? this.onInk,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accentBlue: accentBlue ?? this.accentBlue,
      accentBlueMuted: accentBlueMuted ?? this.accentBlueMuted,
      accentOrange: accentOrange ?? this.accentOrange,
      onAccentOrange: onAccentOrange ?? this.onAccentOrange,
      star: star ?? this.star,
      success: success ?? this.success,
      successMuted: successMuted ?? this.successMuted,
      error: error ?? this.error,
      info: info ?? this.info,
      overlay: overlay ?? this.overlay,
      shelfCurrentlyReading: shelfCurrentlyReading ?? this.shelfCurrentlyReading,
      shelfCompleted: shelfCompleted ?? this.shelfCompleted,
      shelfWantToRead: shelfWantToRead ?? this.shelfWantToRead,
      shelfFavorites: shelfFavorites ?? this.shelfFavorites,
    );
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) return this;
    return AppColorTokens(
      background: Color.lerp(background, other.background, t)!,
      authBackground: Color.lerp(authBackground, other.authBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      onInk: Color.lerp(onInk, other.onInk, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accentBlue: Color.lerp(accentBlue, other.accentBlue, t)!,
      accentBlueMuted: Color.lerp(accentBlueMuted, other.accentBlueMuted, t)!,
      accentOrange: Color.lerp(accentOrange, other.accentOrange, t)!,
      onAccentOrange: Color.lerp(onAccentOrange, other.onAccentOrange, t)!,
      star: Color.lerp(star, other.star, t)!,
      success: Color.lerp(success, other.success, t)!,
      successMuted: Color.lerp(successMuted, other.successMuted, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      shelfCurrentlyReading: Color.lerp(shelfCurrentlyReading, other.shelfCurrentlyReading, t)!,
      shelfCompleted: Color.lerp(shelfCompleted, other.shelfCompleted, t)!,
      shelfWantToRead: Color.lerp(shelfWantToRead, other.shelfWantToRead, t)!,
      shelfFavorites: Color.lerp(shelfFavorites, other.shelfFavorites, t)!,
    );
  }
}

extension AppColorTokensContext on BuildContext {
  AppColorTokens get colors => Theme.of(this).extension<AppColorTokens>()!;
}
