import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where to send the user after a successful login. Captured right before
/// they're sent to the Login screen — either by the router's own redirect
/// guard (tapping a gated tab like Notifications) or by `ensureLoggedIn`'s
/// action-level prompt (Add to Cart, wishlist, …) — so signing in drops
/// them back where they were instead of always bouncing to Home. Cleared
/// (consumed) the moment it's used, in app_router.dart's redirect.
final pendingReturnLocationProvider = StateProvider<String?>((ref) => null);
