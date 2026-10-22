import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      builder: (context, child) => _WebFrameRouterSync(
        router: router,
        child: child!,
      ),
    );
  }
}

/// Safely syncs web frame width with current router route without triggering
/// "setState() or markNeedsBuild() called during build" during router initialization.
class _WebFrameRouterSync extends StatefulWidget {
  const _WebFrameRouterSync({required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  State<_WebFrameRouterSync> createState() => _WebFrameRouterSyncState();
}

class _WebFrameRouterSyncState extends State<_WebFrameRouterSync> {
  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void didUpdateWidget(_WebFrameRouterSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routerDelegate.removeListener(_onRouteChanged);
      widget.router.routerDelegate.addListener(_onRouteChanged);
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    // If the router notifies during a build phase (e.g. during initial route
    // resolution on web), defer setState to the next frame to prevent
    // "setState() or markNeedsBuild() called during build" assertion failures.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.router.routerDelegate.currentConfiguration.uri.path;
    return _WebFrame(
      // The admin panel uses the full width for its sidebar and tables.
      enabled: !path.startsWith('/admin'),
      child: widget.child,
    );
  }
}
