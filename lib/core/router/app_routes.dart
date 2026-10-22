/// Route path/name constants shared between the router config and any
/// screen that needs to navigate.
abstract final class AppRoute {
  static const auth = '/auth';

  static const splash = '/splash';

  static const home = '/home';
  static const explore = '/explore';
  static const store = '/store';
  static const orders = '/orders';
  static const vouchers = '/vouchers';
  static const notifications = '/notifications';
  static const messages = '/messages';
  static const library = '/library';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';

  static const bookDetails = 'book'; // pushed relative to the active tab, e.g. /home/book/:id
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orderConfirmation = '/order-confirmation';

  /// Admin-only — see the redirect guard in app_router.dart.
  static const admin = '/admin';
  static const adminProducts = '/admin/products';
  static const adminOrders = '/admin/orders';
  static const adminVouchers = '/admin/vouchers'; // + '/new' or '/:id'
  static const adminMessages = '/admin/messages'; // + '/:uid'
  static const adminAddProduct = '/admin/product';
  static const adminEditProduct = '/admin/product'; // + '/:id/edit'
  static const adminSellers = '/admin/sellers';
  static const adminListings = '/admin/listings';

  /// Seller Center — shows the application form until the user's store is
  /// approved. Store data is protected by RLS, not by these routes.
  static const seller = '/seller';
  static const sellerProducts = '/seller/products';
  static const sellerOrders = '/seller/orders';
  static const sellerAddProduct = '/seller/product';
  static const sellerEditProduct = '/seller/product'; // + '/:id/edit'
  static const sellerMessages = '/seller/messages'; // + '/:uid?storeId=...'
}
