import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../models/order.dart' show OrderStatus;
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_listings_screen.dart';
import '../../features/admin/presentation/admin_messages_screen.dart';
import '../../features/admin/presentation/admin_orders_screen.dart';
import '../../features/admin/presentation/admin_product_form_screen.dart';
import '../../features/admin/presentation/admin_products_screen.dart';
import '../../features/admin/presentation/admin_voucher_form_screen.dart';
import '../../features/admin/presentation/admin_vouchers_screen.dart';
import '../../features/admin/presentation/admin_providers.dart';
import '../../features/admin/presentation/admin_sellers_screen.dart';
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/book_details/presentation/book_details_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/catalog/presentation/explore_screen.dart';
import '../../features/catalog/presentation/home_screen.dart';
import '../../features/catalog/presentation/store_screen.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/checkout/presentation/order_confirmation_screen.dart';
import '../../features/checkout/presentation/order_detail_screen.dart';
import '../../features/checkout/presentation/orders_screen.dart';
import '../../features/library/presentation/collection_detail_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/messages/presentation/conversation_screen.dart';
import '../../features/messages/presentation/messages_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/splash_ad_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reviews/presentation/reviews_list_screen.dart';
import '../../features/seller/presentation/seller_center_screen.dart';
import '../../features/seller/presentation/seller_conversation_screen.dart';
import '../../features/seller/presentation/seller_messages_screen.dart';
import '../../features/seller/presentation/seller_orders_screen.dart';
import '../../features/seller/presentation/seller_products_screen.dart';
import '../../features/vouchers/presentation/coupon_detail_screen.dart';
import '../../features/vouchers/presentation/vouchers_screen.dart';
import '../auth/pending_return_location.dart';
import '../dev/dev_preview.dart';
import '../onboarding/launch_prefs.dart';
import '../widgets/app_shell.dart';
import 'app_routes.dart';
import 'go_router_refresh_stream.dart';
import 'page_transitions.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Rebuilding the router when guest-preview mode or the splash-seen flag
  // toggles is a bit heavy, but each only ever changes once per debug
  // session/install respectively — see core/dev/dev_preview.dart and
  // core/onboarding/launch_prefs.dart.
  final isGuestPreview = ref.watch(devGuestModeProvider);
  final hasSeenSplash = ref.watch(hasSeenLaunchSplashProvider);

  return GoRouter(
    initialLocation: AppRoute.home,
    refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
    redirect: (context, state) {
      // The first-launch splash/ad screen takes priority over everything
      // else, including the auth gate below — it's pre-login marketing,
      // not an account screen. Once seen (this session's in-memory flag,
      // backed by SharedPreferences — see launch_prefs.dart) it never
      // redirects here again.
      final isSplashRoute = state.matchedLocation == AppRoute.splash;
      if (!hasSeenSplash && !isSplashRoute) return AppRoute.splash;
      if (isSplashRoute) return null;

      // Reads Supabase auth directly (not the Riverpod authStateProvider)
      // because refreshListenable above subscribes to the very same
      // auth stream separately — going through Riverpod here raced
      // that second subscription and could still see the old (logged-out)
      // value the instant sign-in completed, redirecting straight back to
      // /auth. `currentUser` is synchronous and always current.
      final isLoggedIn = Supabase.instance.client.auth.currentUser != null || isGuestPreview;
      final isAuthRoute = state.matchedLocation == AppRoute.auth;

      // Shopee-style: browsing (Home/Store/Vouchers/Explore/Book Details/
      // Reviews) needs no account. Everything account-specific — Cart,
      // Checkout, Orders, Notifications, Messages, Library, Admin — still
      // redirects to Login (capturing where they were, so login can drop
      // them back here — see pending_return_location.dart). Individual
      // write actions reachable from a guest-browsable screen (Add to
      // Cart, wishlist, etc.) are guarded separately at the call site —
      // see core/auth/require_login.dart — since those don't navigate
      // anywhere for this redirect to catch.
      if (!isLoggedIn && !isAuthRoute && _requiresAuth(state.matchedLocation)) {
        ref.read(pendingReturnLocationProvider.notifier).state = state.matchedLocation;
        return AppRoute.auth;
      }
      // A plain safety net (e.g. browser back-button lands back on /auth
      // while already signed in) — NOT what sends a just-logged-in user to
      // their intended page. That's handled explicitly and deterministically
      // in auth_screen.dart's `_goToReturnLocation`, tied to the "Got it"
      // tap rather than this redirect's auth-stream timing, which isn't
      // guaranteed to resolve before the dialog closes. If this branch also
      // consumed `pendingReturnLocationProvider`, whichever of the two fired
      // first would clear it out from under the other.
      final isAdmin = ref.read(isAdminProvider);

      if (isLoggedIn && isAuthRoute) {
        return isAdmin ? AppRoute.admin : AppRoute.home;
      }

      // Admin routes are guarded here too, not just hidden from the UI, so
      // a non-admin can't reach them by deep link either.
      if (state.matchedLocation.startsWith('/admin') && !isAdmin) {
        return AppRoute.home;
      }

      // Admins only have the Admin Panel — they cannot shop, order, or use customer cart/checkout.
      if (isLoggedIn && isAdmin && !state.matchedLocation.startsWith('/admin')) {
        // Allow profile (for settings/logout), auth, and messages
        const adminAllowed = [AppRoute.profile, AppRoute.auth, '/messages', '/admin', AppRoute.orders];
        final isAllowed = adminAllowed.any(
          (p) => state.matchedLocation == p || state.matchedLocation.startsWith('$p/'),
        );
        if (!isAllowed) return AppRoute.admin;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoute.splash,
        pageBuilder: (context, state) => buildSmoothPage(state: state, child: const SplashAdScreen()),
      ),
      GoRoute(
        path: AppRoute.auth,
        pageBuilder: (context, state) => buildSmoothPage(state: state, child: const AuthScreen(), slideFromBottom: true),
      ),
      GoRoute(
        path: AppRoute.cart,
        pageBuilder: (context, state) => buildSmoothPage(state: state, child: const CartScreen(), slideFromBottom: true),
      ),
      GoRoute(
        path: AppRoute.checkout,
        pageBuilder: (context, state) => buildSmoothPage(state: state, child: const CheckoutScreen()),
      ),
      GoRoute(
        path: '${AppRoute.orderConfirmation}/:orderId',
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: OrderConfirmationScreen(orderId: state.pathParameters['orderId']!),
        ),
      ),
      // Every /admin page shares the admin shell (a sidebar on wide screens).
      ShellRoute(
        builder: (context, state, child) => AdminShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: AppRoute.admin, builder: (context, state) => const AdminDashboardScreen()),
          GoRoute(path: AppRoute.adminProducts, builder: (context, state) => const AdminProductsScreen()),
          GoRoute(
            path: AppRoute.adminOrders,
            builder: (context, state) => AdminOrdersScreen(initialStatus: state.extra as OrderStatus?),
          ),
          GoRoute(
            path: AppRoute.adminVouchers,
            builder: (context, state) => const AdminVouchersScreen(),
            routes: [
              GoRoute(
                path: 'new',
                pageBuilder: (context, state) => buildSmoothPage(state: state, child: const AdminVoucherFormScreen()),
              ),
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) => buildSmoothPage(
                  state: state,
                  child: AdminVoucherFormScreen(voucherId: state.pathParameters['id']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoute.adminMessages,
            builder: (context, state) => const AdminMessagesScreen(),
            routes: [
              GoRoute(
                path: ':convId',
                pageBuilder: (context, state) => buildSmoothPage(
                  state: state,
                  child: AdminConversationScreen(
                    conversationId: state.pathParameters['convId']!,
                    buyerName: state.uri.queryParameters['buyerName'],
                    roleBadge: state.uri.queryParameters['roleBadge'],
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoute.adminAddProduct,
            pageBuilder: (context, state) => buildSmoothPage(state: state, child: const AdminProductFormScreen()),
          ),
          GoRoute(
            path: '${AppRoute.adminEditProduct}/:id/edit',
            pageBuilder: (context, state) => buildSmoothPage(
              state: state,
              child: AdminProductFormScreen(bookId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(path: AppRoute.adminSellers, builder: (context, state) => const AdminSellersScreen()),
          GoRoute(path: AppRoute.adminListings, builder: (context, state) => const AdminListingsScreen()),
        ],
      ),
      GoRoute(
        path: AppRoute.seller,
        pageBuilder: (context, state) => buildSmoothPage(state: state, child: const SellerCenterScreen()),
      ),
      GoRoute(
        path: AppRoute.sellerProducts,
        pageBuilder: (context, state) => buildSmoothPage(state: state, child: const SellerProductsScreen()),
      ),
      GoRoute(
        path: AppRoute.sellerOrders,
        pageBuilder: (context, state) => buildSmoothPage(state: state, child: const SellerOrdersScreen()),
      ),
      GoRoute(
        path: AppRoute.sellerMessages,
        pageBuilder: (context, state) => buildSmoothPage(state: state, child: const SellerMessagesScreen()),
        routes: [
          GoRoute(
            path: ':convId',
            pageBuilder: (context, state) => buildSmoothPage(
              state: state,
              child: SellerConversationScreen(
                conversationId: state.pathParameters['convId']!,
                storeId: state.uri.queryParameters['storeId'] ?? '',
                buyerName: state.uri.queryParameters['buyerName'],
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoute.sellerAddProduct,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: const AdminProductFormScreen(sellerMode: true),
        ),
      ),
      GoRoute(
        path: '${AppRoute.sellerEditProduct}/:id/edit',
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: AdminProductFormScreen(bookId: state.pathParameters['id']!, sellerMode: true),
        ),
      ),
      GoRoute(
        path: AppRoute.editProfile,
        pageBuilder: (context, state) => buildSmoothPage(state: state, child: const EditProfileScreen()),
      ),
      // Pushed (not a nav-shell branch) — reached only via the Home search
      // bar now that Explore is no longer a bottom-nav tab. See item 6.
      GoRoute(
        path: AppRoute.explore,
        pageBuilder: (context, state) => buildSmoothPage(state: state, child: const ExploreScreen()),
        routes: [_bookDetailsRoute()],
      ),
      // Pushed — reached via Profile → "Saved Books" now that Library is no
      // longer a bottom-nav tab (replaced by Notifications). See item 4.
      GoRoute(
        path: AppRoute.library,
        pageBuilder: (context, state) => buildSmoothPage(state: state, child: const LibraryScreen()),
        routes: [
          _bookDetailsRoute(),
          GoRoute(
            path: 'collection/:id',
            pageBuilder: (context, state) => buildSmoothPage(
              state: state,
              child: CollectionDetailScreen(collectionId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      // Pushed — order tracking now lives under Me → "My Orders" (see
      // profile_screen.dart) rather than its own nav tab. `extra` optionally
      // carries an `OrderTab` to deep-link straight into one segment (the
      // Me screen's To Pay/To Ship/To Receive/To Rate icons).
      GoRoute(
        path: AppRoute.orders,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: OrdersScreen(initialTab: state.extra as OrderTab?),
        ),
        routes: [
          GoRoute(
            path: ':orderId',
            pageBuilder: (context, state) => buildSmoothPage(
              state: state,
              child: OrderDetailScreen(orderId: state.pathParameters['orderId']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoute.messages,
        pageBuilder: (context, state) => buildSmoothPage(state: state, child: const MessagesScreen()),
        routes: [
          GoRoute(
            path: 'store',
            pageBuilder: (context, state) => buildSmoothPage(state: state, child: const ConversationScreen()),
          ),
          GoRoute(
            path: 'conversation/:convId',
            pageBuilder: (context, state) => buildSmoothPage(
              state: state,
              child: ConversationScreen(
                conversationId: state.pathParameters['convId'],
                storeId: state.uri.queryParameters['storeId'],
                storeName: state.uri.queryParameters['storeName'],
              ),
            ),
          ),
          GoRoute(
            path: 'seller/:storeId',
            pageBuilder: (context, state) => buildSmoothPage(
              state: state,
              child: ConversationScreen(
                storeId: state.pathParameters['storeId'],
                storeName: state.uri.queryParameters['name'],
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/reviews/:bookId',
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: ReviewsListScreen(bookId: state.pathParameters['bookId']!),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoute.home,
              builder: (context, state) => const HomeScreen(),
              routes: [_bookDetailsRoute()],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoute.vouchers,
              builder: (context, state) => const VouchersScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  pageBuilder: (context, state) => buildSmoothPage(
                    state: state,
                    child: CouponDetailScreen(voucherId: state.pathParameters['id']!),
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoute.store,
              builder: (context, state) => const StoreScreen(),
              routes: [_bookDetailsRoute()],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoute.notifications, builder: (context, state) => const NotificationsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoute.profile, builder: (context, state) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});

GoRoute _bookDetailsRoute() {
  return GoRoute(
    path: '${AppRoute.bookDetails}/:id',
    pageBuilder: (context, state) => buildSmoothPage(
      state: state,
      child: BookDetailsScreen(bookId: state.pathParameters['id']!),
    ),
  );
}

/// Routes a guest can reach without signing in. Nested pushes (book
/// details under Home/Store/Explore, a voucher's detail page) inherit
/// their parent's accessibility via the `startsWith` check.
const _guestAccessiblePrefixes = [
  AppRoute.splash,
  AppRoute.home,
  AppRoute.store,
  AppRoute.vouchers,
  AppRoute.explore,
  '/reviews',
];

bool _requiresAuth(String location) {
  // The Me tab itself is visible to a guest (it shows a "Sign In" prompt
  // instead of a profile — see profile_screen.dart) but NOT its nested
  // `/profile/edit` route, so this is an exact match rather than the
  // `startsWith` prefix check below (which would otherwise also let
  // `/profile/edit` through).
  if (location == AppRoute.profile) return false;

  final isGuestAccessible = _guestAccessiblePrefixes.any(
    (prefix) => location == prefix || location.startsWith('$prefix/'),
  );
  return !isGuestAccessible;
}
