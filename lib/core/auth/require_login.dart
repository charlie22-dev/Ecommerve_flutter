import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../dev/dev_preview.dart';
import '../router/app_routes.dart';
import 'pending_return_location.dart';

/// Guards an account-only action (add to cart, wishlist, rate, message…)
/// reachable from a screen guests are now allowed to browse (Home, Store,
/// Vouchers, Explore, Book Details — see app_router.dart's guest-accessible
/// route list). Returns true if signed in (or in dev guest-preview mode);
/// otherwise pushes to Login and returns false. Call sites should bail out
/// of their own action on `false` instead of performing it against a null
/// uid, which used to silently no-op while still claiming success (e.g.
/// "Added to cart" showing even though nothing was written).
bool ensureLoggedIn(BuildContext context, WidgetRef ref) {
  final isLoggedIn = Supabase.instance.client.auth.currentUser != null || ref.read(devGuestModeProvider);
  if (!isLoggedIn) goToLogin(context, ref);
  return isLoggedIn;
}

/// Remembers the current page (see pending_return_location.dart) and
/// pushes to Login — shared by `ensureLoggedIn` above and any screen with
/// its own explicit "Sign In" button (e.g. the guest Me screen).
void goToLogin(BuildContext context, WidgetRef ref) {
  ref.read(pendingReturnLocationProvider.notifier).state = GoRouterState.of(context).matchedLocation;
  context.push(AppRoute.auth);
}
