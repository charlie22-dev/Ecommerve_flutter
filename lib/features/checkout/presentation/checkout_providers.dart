import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:uuid/uuid.dart';

import '../../../core/models/book.dart';
import '../../cart/domain/cart_line.dart';
import '../../../core/models/order.dart';
import '../../../core/models/shipping_option.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../cart/presentation/cart_providers.dart';
import '../data/checkout_functions_service.dart';
import '../data/order_repository.dart';
import '../data/paymongo_client.dart';
import 'address_providers.dart';
import 'voucher_providers.dart';

/// Single item for direct "Buy Now" flow (leaves the shopping cart intact)
class BuyNowItem {
  const BuyNowItem({required this.book, this.quantity = 1});
  final Book book;
  final int quantity;
}

final buyNowItemProvider = StateProvider<BuyNowItem?>((ref) => null);

/// Active lines for checkout:
/// - If Buy Now: the single selected item
/// - If cart checkout: only the items the user has selected (checked) in the cart
final checkoutLinesProvider = Provider<AsyncValue<List<CartLine>>>((ref) {
  final buyNow = ref.watch(buyNowItemProvider);
  if (buyNow != null) {
    return AsyncData([CartLine(book: buyNow.book, quantity: buyNow.quantity)]);
  }
  // Filter cart lines by the user's checked selection
  final cartAsync = ref.watch(cartLinesProvider);
  final selectedIds = ref.watch(selectedCartBookIdsProvider);
  return cartAsync.whenData((lines) {
    if (selectedIds == null) {
      // Default: all in-stock items selected
      return lines.where((l) => l.book.inStock).toList();
    }
    return lines.where((l) => selectedIds.contains(l.book.id)).toList();
  });
});

final orderRepositoryProvider = Provider((ref) => OrderRepository());
final checkoutFunctionsServiceProvider = Provider(
  (ref) => CheckoutFunctionsService(),
);
final paymongoClientProvider = Provider((ref) => PaymongoClient());

// Cash on Delivery is the default payment method
final selectedPaymentMethodProvider = StateProvider<PaymentMethod>(
  (ref) => PaymentMethod.cashOnDelivery,
);

final selectedShippingOptionProvider = StateProvider<ShippingOption>(
  (ref) => ShippingOption.standard,
);

final orderStreamProvider = StreamProvider.autoDispose.family<Order?, String>((
  ref,
  orderId,
) {
  final repository = ref.watch(orderRepositoryProvider);
  final controller = StreamController<Order?>();
  Order? latest;
  var checking = false;
  var closed = false;
  var initialCheckStarted = false;
  Future<void> verify() async {
    final order = latest;
    if (closed ||
        checking ||
        order == null ||
        order.isPaid ||
        order.paymentMethod == PaymentMethod.cashOnDelivery ||
        order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.failed) {
      return;
    }
    checking = true;
    try {
      final updated = await repository.refreshPayment(orderId);
      if (!closed && updated != null) {
        latest = updated;
        controller.add(updated);
      }
    } catch (_) {
      // Keep the last known receipt while offline.
    } finally {
      checking = false;
    }
  }

  final subscription = repository
      .watchOrder(orderId)
      .listen(
        (order) {
          if (closed) return;
          latest = order;
          controller.add(order);
          if (!initialCheckStarted && order != null) {
            initialCheckStarted = true;
            verify();
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!closed) controller.addError(error, stack);
        },
      );
  final timer = Timer.periodic(const Duration(seconds: 5), (_) => verify());
  ref.onDispose(() {
    closed = true;
    timer.cancel();
    subscription.cancel();
    controller.close();
  });
  return controller.stream;
});

final userOrdersProvider = StreamProvider<List<Order>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(orderRepositoryProvider).watchOrdersForUser(uid);
});

sealed class CheckoutResult {
  const CheckoutResult();
}

class CheckoutAwaitingRedirect extends CheckoutResult {
  const CheckoutAwaitingRedirect(this.orderId, this.checkoutUrl);
  final String orderId;
  final String checkoutUrl;
}

class CheckoutSucceeded extends CheckoutResult {
  const CheckoutSucceeded(this.orderId);
  final String orderId;
}

class CheckoutFailed extends CheckoutResult {
  const CheckoutFailed(this.message, {this.orderId});
  final String message;
  final String? orderId;
}

final checkoutControllerProvider =
    AsyncNotifierProvider<CheckoutController, void>(CheckoutController.new);

class CheckoutController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<List<OrderLineItem>> _lineItems() async {
    final buyNow = ref.read(buyNowItemProvider);
    if (buyNow != null) {
      return [
        OrderLineItem(
          bookId: buyNow.book.id,
          title: buyNow.book.title,
          coverUrl: buyNow.book.coverUrl,
          unitPrice: buyNow.book.price,
          quantity: buyNow.quantity,
        ),
      ];
    }
    final allLines = await ref.read(cartLinesProvider.future);
    final selectedIds = ref.read(selectedCartBookIdsProvider);
    final selectedLines = selectedIds == null
        ? allLines.where((l) => l.book.inStock).toList()
        : allLines.where((l) => selectedIds.contains(l.book.id)).toList();

    return selectedLines
        .map(
          (l) => OrderLineItem(
            bookId: l.book.id,
            title: l.book.title,
            coverUrl: l.book.coverUrl,
            unitPrice: l.book.price,
            quantity: l.quantity,
          ),
        )
        .toList();
  }

  /// One key per checkout attempt, so a retry after a lost response gets
  /// the same order back instead of a second one. Cleared once it succeeds.
  String? _idempotencyKey;
  String? _attemptSignature;

  void endCheckout() {
    _idempotencyKey = null;
    _attemptSignature = null;
  }

  /// Places the order server-side (see OrderRepository.createOrder). The
  /// returned total is the amount to charge — never the one shown on screen.
  Future<({String id, double total})> _placeOrder(PaymentMethod method) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) throw const _CheckoutError('You must be signed in.');

    final items = await _lineItems();
    if (items.isEmpty) throw const _CheckoutError('Your cart is empty.');

    final address = ref.read(selectedAddressProvider);
    if (address == null) {
      throw const _CheckoutError('Add a shipping address first.');
    }

    final signature =
        '$uid|${ref.read(buyNowItemProvider) == null ? 'cart' : 'buyNow'}|${method.name}|${address.id}|'
        '${ref.read(selectedShippingOptionProvider).id}|${ref.read(appliedVoucherProvider)?.code}|'
        '${items.map((i) => '${i.bookId}:${i.quantity}').join(',')}';
    if (_attemptSignature != signature) {
      _attemptSignature = signature;
      _idempotencyKey = const Uuid().v4();
    }

    final order = await ref
        .read(orderRepositoryProvider)
        .createOrder(
          uid: uid,
          items: items,
          addressId: address.id,
          shippingOptionId: ref.read(selectedShippingOptionProvider).id,
          paymentMethod: method,
          voucherCode: ref.read(appliedVoucherProvider)?.code,
          idempotencyKey: _idempotencyKey ??= const Uuid().v4(),
          fromCart: ref.read(buyNowItemProvider) == null,
        );
    return order;
  }

  Future<CheckoutResult> payWithCashOnDelivery() async {
    state = const AsyncLoading();
    try {
      final order = await _placeOrder(PaymentMethod.cashOnDelivery);
      state = const AsyncData(null);
      return CheckoutSucceeded(order.id);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return CheckoutFailed(_friendlyError(e));
    }
  }

  Future<CheckoutResult> payWithEwallet({required String type}) async {
    state = const AsyncLoading();
    String? pendingOrderId;
    try {
      final method = switch (type) {
        'gcash' => PaymentMethod.gcash,
        'maya' => PaymentMethod.maya,
        'card' => PaymentMethod.card,
        _ => throw const _CheckoutError('Choose a supported payment method.'),
      };
      final order = await _placeOrder(method);
      pendingOrderId = order.id;
      final email = ref.read(authStateProvider).value?.email;
      final invoice = await ref
          .read(checkoutFunctionsServiceProvider)
          .createXenditInvoice(
            orderId: order.id,
            amount: order.total,
            description: 'Order #${order.id.substring(0, 8).toUpperCase()}',
            customerEmail: email,
            paymentMethod: type,
          );

      final invoiceUrl =
          (invoice['invoice_url'] ?? invoice['invoiceUrl']) as String;
      state = const AsyncData(null);
      return CheckoutAwaitingRedirect(order.id, invoiceUrl);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return CheckoutFailed(_friendlyError(e), orderId: pendingOrderId);
    }
  }

  Future<CheckoutResult> payWithCard({
    required String cardNumber,
    required int expMonth,
    required int expYear,
    required String cvc,
    required String billingName,
    required String billingEmail,
  }) async {
    state = const AsyncLoading();
    String? pendingOrderId;
    try {
      final order = await _placeOrder(PaymentMethod.card);
      pendingOrderId = order.id;
      final email = billingEmail.isNotEmpty
          ? billingEmail
          : ref.read(authStateProvider).value?.email;
      final invoice = await ref
          .read(checkoutFunctionsServiceProvider)
          .createXenditInvoice(
            orderId: order.id,
            amount: order.total,
            description: 'Order #${order.id.substring(0, 8).toUpperCase()}',
            customerEmail: email,
            paymentMethod: 'card',
          );

      final invoiceUrl =
          (invoice['invoice_url'] ?? invoice['invoiceUrl']) as String;
      state = const AsyncData(null);
      return CheckoutAwaitingRedirect(order.id, invoiceUrl);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return CheckoutFailed(_friendlyError(e), orderId: pendingOrderId);
    }
  }

  Future<void> clearCartAfterPayment(String orderId) async {
    final order = await ref.read(orderRepositoryProvider).getOrder(orderId);
    if (order == null || order.uid != ref.read(authStateProvider).value?.uid) {
      return;
    }
    if (order.status == OrderStatus.pending ||
        order.status == OrderStatus.failed ||
        order.status == OrderStatus.cancelled) {
      return;
    }
    final buyNow = ref.read(buyNowItemProvider);
    if (buyNow != null) {
      // Direct buy completed: do NOT wipe out user's shopping cart!
      ref.read(buyNowItemProvider.notifier).state = null;
    } else {
      // The database removes purchased quantities atomically when COD is
      // placed or the payment webhook confirms payment, even after app exit.
      ref.invalidate(cartItemsProvider);
      ref.invalidate(cartLinesProvider);
      ref.read(selectedCartBookIdsProvider.notifier).state = null;
    }
    ref.read(appliedVoucherProvider.notifier).state = null;
    _idempotencyKey = null;
    _attemptSignature = null;
  }
}

class _CheckoutError implements Exception {
  const _CheckoutError(this.message);
  final String message;
}

/// Turns backend errors into something a shopper can act on. Messages
/// raised by `place_order` / `apply_order_stock` (code P0001) are written for
/// shoppers, so they're shown as-is.
String _friendlyError(Object e) {
  if (e is _CheckoutError) return e.message;
  if (e is PostgrestException) {
    if (e.hint == 'out_of_stock' || e.message.startsWith('Out of stock')) {
      return '${e.message}. Please lower the quantity or remove it from your cart.';
    }
    if (e.code == 'P0001') return e.message;
    return 'Could not place your order. Please try again.';
  }
  return e.toString();
}
