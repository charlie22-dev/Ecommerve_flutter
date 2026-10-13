import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/auth/presentation/oauth_return.dart';

class BookVerseApp extends ConsumerStatefulWidget {
  const BookVerseApp({super.key});

  @override
  ConsumerState<BookVerseApp> createState() => _BookVerseAppState();
}

class _BookVerseAppState extends ConsumerState<BookVerseApp> {
  @override
  void initState() {
    super.initState();
    // Back from Google/Facebook on web? Show the login popup now.
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => OAuthReturn.completeIfPending(ref.read(appRouterProvider)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.light;

    return MaterialApp.router(
      title: 'BookVerse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
