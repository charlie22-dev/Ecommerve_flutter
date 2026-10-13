import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:uuid/uuid.dart';

import '../../../core/models/order.dart';
import '../../../core/models/shipping_option.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../cart/presentation/cart_providers.dart';
import '../data/checkout_functions_service.dart';
import '../data/order_repository.dart';
import '../data/paymongo_client.dart';
import 'address_providers.dart';
import 'voucher_providers.dart';

final orderRepositoryProvider = Provider((ref) => OrderRepository());
final checkoutFunctionsServiceProvider = Provider((ref) => CheckoutFunctionsService());
final paymongoClientProvider = Provider((ref) => PaymongoClient());

// Cash on Delivery is the default because it's the one method that
// actually completes end-to-end without a real payment backend — see
// checkout_providers.dart's CheckoutController doc comment.
final selectedPaymentMethodProvider = StateProvider<PaymentMethod>((ref) => PaymentMethod.cashOnDelivery);

final selectedShippingOptionProvider = StateProvider<ShippingOption>((ref) => ShippingOption.standard);

final orderStreamProvider = StreamProvider.family<Order?, String>((ref, orderId) {
  return ref.watch(orderRepositoryProvider).watchOrder(orderId);
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
  const CheckoutFailed(this.message);
  final String message;
}

final checkoutControllerProvider =
    AsyncNotifierProvider<CheckoutController, void>(CheckoutController.new);

/// Only `payWithCashOnDelivery` can actually complete right now: GCash/
/// Maya/Card call Cloud Functions that were never built (no `functions/`
/// source, nothing deployed) which would themselves call PayMongo with a
/// placeholder public key (see core/config/paymongo_config.dart) — so
/// those three are wired up structurally but will fail until a real
/// PayMongo account + deployed backend exist. COD needs neither.
class CheckoutController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<List<OrderLineItem>> _lineItems() async {
    final lines = await ref.read(cartLinesProvider.future);
    return lines
        .map((l) => OrderLineItem(
              bookId: l.book.id,
              title: l.book.title,
              coverUrl: l.book.coverUrl,
              unitPrice: l.book.price,
              quantity: l.quantity,
            ))
        .toList();
  }

  /// One key per checkout attempt, so a retry after a lost response gets
  /// the same order back instead of a second one. Cleared once it succeeds.
  String? _idempotencyKey;

  /// Places the order server-side (see OrderRepository.createOrder). The
  /// returned total is the amount to charge — never the one shown on screen.
  Future<({String id, double total})> _placeOrder(PaymentMethod method) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) throw const _CheckoutError('You must be signed in.');

    final items = await _lineItems();
    if (items.isEmpty) throw const _CheckoutError('Your cart is empty.');

    final address = ref.read(selectedAddressProvider);
    if (address == null) throw const _CheckoutError('Add a shipping address first.');

    final order = await ref.read(orderRepositoryProvider).createOrder(
          uid: uid,
          items: items,
          addressId: address.id,
          shippingOptionId: ref.read(selectedShippingOptionProvider).id,
          paymentMethod: method,
          voucherCode: ref.read(appliedVoucherProvider)?.code,
          idempotencyKey: _idempotencyKey ??= const Uuid().v4(),
        );
    _idempotencyKey = null;
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
    try {
      final order = await _placeOrder(type == 'gcash' ? PaymentMethod.gcash : PaymentMethod.maya);
      final checkoutUrl = await ref.read(checkoutFunctionsServiceProvider).createEwalletSource(
            orderId: order.id,
            amount: order.total,
            type: type,
          );

      state = const AsyncData(null);
      return CheckoutAwaitingRedirect(order.id, checkoutUrl);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return CheckoutFailed(_friendlyError(e));
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
    try {
      final order = await _placeOrder(PaymentMethod.card);

      final paymentMethodId = await ref.read(paymongoClientProvider).createPaymentMethod(
            cardNumber: cardNumber,
            expMonth: expMonth,
            expYear: expYear,
            cvc: cvc,
            billingName: billingName,
            billingEmail: billingEmail,
          );

      final result = await ref.read(checkoutFunctionsServiceProvider).payWithCard(
            orderId: order.id,
            amount: order.total,
            paymentMethodId: paymentMethodId,
          );

      state = const AsyncData(null);
      if (result.status == 'succeeded') return CheckoutSucceeded(order.id);
      if (result.redirectUrl != null) return CheckoutAwaitingRedirect(order.id, result.redirectUrl!);
      return const CheckoutFailed('Payment could not be completed.');
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return CheckoutFailed(_friendlyError(e));
    }
  }

  Future<void> clearCartAfterPayment() async {
    final lines = ref.read(cartLinesProvider).value ?? const [];
    await ref.read(cartActionsProvider).clear(lines.map((l) => l.book.id).toList());
    ref.read(appliedVoucherProvider.notifier).state = null;
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
