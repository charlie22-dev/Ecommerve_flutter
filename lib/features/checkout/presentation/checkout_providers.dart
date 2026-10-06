import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

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

  ({double subtotal, double shippingCost, double voucherDiscount}) _totals(
    List<OrderLineItem> items,
    ShippingOption shipping,
  ) {
    final subtotal = items.fold<double>(0, (sum, i) => sum + i.lineTotal);
    final voucher = ref.read(appliedVoucherProvider);
    final voucherDiscount = voucher?.discountFor(subtotal) ?? 0;
    return (subtotal: subtotal, shippingCost: shipping.costFor(subtotal), voucherDiscount: voucherDiscount);
  }

  Future<CheckoutResult> payWithCashOnDelivery() async {
    state = const AsyncLoading();
    try {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid == null) return const CheckoutFailed('You must be signed in.');

      final items = await _lineItems();
      if (items.isEmpty) return const CheckoutFailed('Your cart is empty.');

      final address = ref.read(selectedAddressProvider);
      if (address == null) return const CheckoutFailed('Add a shipping address first.');

      final shipping = ref.read(selectedShippingOptionProvider);
      final totals = _totals(items, shipping);
      final voucher = ref.read(appliedVoucherProvider);

      final orderId = await ref.read(orderRepositoryProvider).createOrder(
            uid: uid,
            items: items,
            subtotal: totals.subtotal,
            shippingCost: totals.shippingCost,
            shippingOptionId: shipping.id,
            shippingAddress: address,
            paymentMethod: PaymentMethod.cashOnDelivery,
            voucherCode: voucher?.code,
            voucherDiscount: totals.voucherDiscount,
          );

      state = const AsyncData(null);
      return CheckoutSucceeded(orderId);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return CheckoutFailed(_friendlyError(e));
    }
  }

  Future<CheckoutResult> payWithEwallet({required String type}) async {
    state = const AsyncLoading();
    try {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid == null) return const CheckoutFailed('You must be signed in.');

      final items = await _lineItems();
      if (items.isEmpty) return const CheckoutFailed('Your cart is empty.');

      final address = ref.read(selectedAddressProvider);
      if (address == null) return const CheckoutFailed('Add a shipping address first.');

      final shipping = ref.read(selectedShippingOptionProvider);
      final totals = _totals(items, shipping);
      final voucher = ref.read(appliedVoucherProvider);
      final method = type == 'gcash' ? PaymentMethod.gcash : PaymentMethod.maya;

      final orderId = await ref.read(orderRepositoryProvider).createOrder(
            uid: uid,
            items: items,
            subtotal: totals.subtotal,
            shippingCost: totals.shippingCost,
            shippingOptionId: shipping.id,
            shippingAddress: address,
            paymentMethod: method,
            voucherCode: voucher?.code,
            voucherDiscount: totals.voucherDiscount,
          );

      final checkoutUrl = await ref.read(checkoutFunctionsServiceProvider).createEwalletSource(
            orderId: orderId,
            amount: totals.subtotal + totals.shippingCost - totals.voucherDiscount,
            type: type,
          );

      state = const AsyncData(null);
      return CheckoutAwaitingRedirect(orderId, checkoutUrl);
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
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid == null) return const CheckoutFailed('You must be signed in.');

      final items = await _lineItems();
      if (items.isEmpty) return const CheckoutFailed('Your cart is empty.');

      final address = ref.read(selectedAddressProvider);
      if (address == null) return const CheckoutFailed('Add a shipping address first.');

      final shipping = ref.read(selectedShippingOptionProvider);
      final totals = _totals(items, shipping);
      final voucher = ref.read(appliedVoucherProvider);

      final orderId = await ref.read(orderRepositoryProvider).createOrder(
            uid: uid,
            items: items,
            subtotal: totals.subtotal,
            shippingCost: totals.shippingCost,
            shippingOptionId: shipping.id,
            shippingAddress: address,
            paymentMethod: PaymentMethod.card,
            voucherCode: voucher?.code,
            voucherDiscount: totals.voucherDiscount,
          );

      final paymentMethodId = await ref.read(paymongoClientProvider).createPaymentMethod(
            cardNumber: cardNumber,
            expMonth: expMonth,
            expYear: expYear,
            cvc: cvc,
            billingName: billingName,
            billingEmail: billingEmail,
          );

      final result = await ref.read(checkoutFunctionsServiceProvider).payWithCard(
            orderId: orderId,
            amount: totals.subtotal + totals.shippingCost - totals.voucherDiscount,
            paymentMethodId: paymentMethodId,
          );

      state = const AsyncData(null);
      if (result.status == 'succeeded') return CheckoutSucceeded(orderId);
      if (result.redirectUrl != null) return CheckoutAwaitingRedirect(orderId, result.redirectUrl!);
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

/// Turns backend errors into something a shopper can act on — mainly the
/// "Out of stock: <title>" raised by the `apply_order_stock` trigger.
String _friendlyError(Object e) {
  if (e is PostgrestException) {
    if (e.hint == 'out_of_stock' || e.message.startsWith('Out of stock')) {
      return '${e.message}. Please lower the quantity or remove it from your cart.';
    }
    return 'Could not place your order. Please try again.';
  }
  return e.toString();
}
