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
}
