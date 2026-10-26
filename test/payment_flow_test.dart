import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_app/core/models/order.dart';
import 'package:my_app/core/theme/app_color_tokens.dart';
import 'package:my_app/features/checkout/presentation/checkout_providers.dart';
import 'package:my_app/features/checkout/presentation/order_confirmation_screen.dart';
import 'package:my_app/features/checkout/presentation/order_detail_screen.dart';
import 'package:my_app/features/checkout/presentation/payment_webview_screen.dart';
import 'package:my_app/features/checkout/data/order_repository.dart';
import 'package:my_app/features/admin/presentation/admin_providers.dart';
import 'package:my_app/features/auth/presentation/auth_providers.dart';
import 'package:my_app/features/seller/presentation/seller_providers.dart';

class VerifyingOrderRepository extends OrderRepository {
  int verificationCalls = 0;
  Order? verified;
  @override
  Stream<Order?> watchOrder(String orderId) => Stream.value(sample());
  @override
  Future<Order?> refreshPayment(String orderId) async {
    verificationCalls++;
    return verified ?? sample();
  }
}

Order sample({OrderStatus status = OrderStatus.pending, DateTime? paidAt}) =>
    Order(
      id: '12345678-0000-4000-8000-000000000001',
      uid: 'buyer',
      items: const [],
      subtotal: 500,
      shippingCost: 60,
      taxAmount: 60,
      voucherCode: null,
      voucherDiscount: 0,
      total: 620,
      shippingAddress: null,
      shippingOptionId: 'standard',
      paymentMethod: PaymentMethod.gcash,
      status: status,
      paidAt: paidAt,
    );

ThemeData get theme => ThemeData(extensions: const [AppColorTokens.light]);

void main() {
  testWidgets(
    'receipt reconciles a missed webhook and shows the actual paid channel',
    (tester) async {
      final repository = VerifyingOrderRepository();
      final paid = Order.fromRow({
        ...sample(
          status: OrderStatus.toShip,
          paidAt: DateTime.utc(2026),
        ).toRow(),
        'payment_status': 'paid',
        'payment_channel': 'GRABPAY',
        'xendit_payment_id': 'payment-reference-123',
        'amount_paid': 620,
        'payment_currency': 'PHP',
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderRepositoryProvider.overrideWithValue(repository),
            isAdminProvider.overrideWith((_) => false),
            authStateProvider.overrideWith((_) => Stream.value(null)),
            orderShipmentsProvider(paid.id)
                .overrideWith((_) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: theme,
            home: OrderDetailScreen(orderId: paid.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.verificationCalls, 1);
      repository.verified = paid;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Paid'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('GrabPay'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('payment-reference-123'), findsOneWidget);
      final calls = repository.verificationCalls;
      await tester.pump(const Duration(seconds: 10));
      expect(
        repository.verificationCalls,
        calls,
        reason: 'Confirmed orders stop polling the payment provider',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('checking payment cannot confirm a pending or unpaid order', (
    tester,
  ) async {
    var current = sample();
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => PaymentWebViewScreen(
                      checkoutUrl: 'https://example.com/invoice',
                      orderId: current.id,
                      openCheckout: false,
                      loadOrder: (_) async => current,
                    ),
                  ),
                );
              },
              child: const Text('Pay'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check payment status'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(
      find.textContaining('Awaiting payment confirmation'),
      findsOneWidget,
    );

    current = sample(status: OrderStatus.toShip);
    await tester.tap(find.text('Check payment status'));
    await tester.pumpAndSettle();
    expect(result, isNull, reason: 'A status alone is not payment evidence');

    current = sample(status: OrderStatus.toReceive, paidAt: DateTime.utc(2026));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(
      result,
      isTrue,
      reason: 'Delayed server confirmation completes automatically',
    );
    expect(find.text('Pay'), findsOneWidget);
  });

  testWidgets('failed payment returns false without a success screen', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => PaymentWebViewScreen(
                      checkoutUrl: 'https://example.com/invoice',
                      orderId: sample().id,
                      openCheckout: false,
                      loadOrder: (_) async =>
                          sample(status: OrderStatus.failed),
                    ),
                  ),
                );
              },
              child: const Text('Pay'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  for (final useSystemBack in [false, true]) {
    testWidgets(
      'order details returns Home using ${useSystemBack ? 'device' : 'top'} back',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/orders/receipt',
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const Scaffold(body: Text('Home destination')),
            ),
            GoRoute(
              path: '/orders/:id',
              builder: (_, _) => const OrderDetailScreen(orderId: 'receipt'),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              orderStreamProvider('receipt')
                  .overrideWith((_) => Stream.value(null)),
            ],
            child: MaterialApp.router(theme: theme, routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        if (useSystemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byTooltip('Home'));
        }
        await tester.pumpAndSettle();
        expect(find.text('Home destination'), findsOneWidget);
      },
    );
  }

  testWidgets('confirmation link shows pending rather than claiming success', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderStreamProvider('receipt')
              .overrideWith((_) => Stream.value(sample())),
        ],
        child: MaterialApp(
          theme: theme,
          home: const OrderConfirmationScreen(orderId: 'receipt'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Awaiting payment confirmation.'), findsOneWidget);
    expect(find.text('Payment Successful!'), findsNothing);
  });
}
