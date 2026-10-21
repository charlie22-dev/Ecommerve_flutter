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

/// On big screens, centers the storefront at a comfortable reading width,
/// like any shop website, instead of stretching phone layouts edge to edge.
/// MediaQuery is narrowed too, so screens lay out for the width they get.
class _WebFrame extends StatelessWidget {
  const _WebFrame({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  static const maxWidth = 1200.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (!enabled || mq.size.width <= maxWidth) return child;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: SizedBox(
          width: maxWidth,
          child: MediaQuery(data: mq.copyWith(size: Size(maxWidth, mq.size.height)), child: child),
        ),
      ),
    );
  }
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
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.dark;

    return MaterialApp.router(
      title: 'BookVerse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => ListenableBuilder(
        listenable: router.routerDelegate,
        builder: (context, _) => _WebFrame(
          // The admin panel uses the full width for its sidebar and tables.
          enabled: !router.routerDelegate.currentConfiguration.uri.path.startsWith('/admin'),
          child: child!,
        ),
      ),
    );
  }
}
