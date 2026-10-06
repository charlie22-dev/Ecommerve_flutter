import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapts a `Stream` (Supabase auth state changes) into a `Listenable` so
/// `GoRouter`'s `refreshListenable` re-evaluates redirects whenever
/// sign-in state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
