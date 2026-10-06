// Smoke test: the app's Supabase bootstrap in main() needs a platform
// channel that isn't available under `flutter test`, so this checks the
// piece that doesn't need it — the theme builds without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/core/theme/app_theme.dart';

void main() {
  // AppTheme uses google_fonts, which needs the services binding to look up
  // bundled font assets. Runtime fetching is off because `flutter test`
  // blocks real HTTP — text simply falls back to the default font.
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('AppTheme.light builds a valid ThemeData', () {
    final theme = AppTheme.light;
    expect(theme.brightness, Brightness.light);
  });
}
