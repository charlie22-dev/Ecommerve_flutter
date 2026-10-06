import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/order.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/primary_button.dart';
import 'checkout_providers.dart';

class OrderConfirmationScreen extends ConsumerWidget {
  const OrderConfirmationScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderStreamProvider(orderId));

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: orderAsync.when(
              data: (order) => _ConfirmationBody(order: order),
              loading: () => CircularProgressIndicator(color: context.colors.ink),
              error: (err, _) => Text(
                'Could not load this order.',
                style: TextStyle(color: context.colors.error),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmationBody extends StatelessWidget {
  const _ConfirmationBody({required this.order});
  final Order? order;

  @override
  Widget build(BuildContext context) {
    if (order == null) {
      return Text('Order not found.', style: TextStyle(color: context.colors.textSecondary));
    }

    final isPending = order!.status == OrderStatus.pending;
    // "Confirmed" covers everything past pending-payment: toShip (COD
    // placed, or online payment confirmed), toReceive, completed.
    final isConfirmed = order!.status == OrderStatus.toShip ||
        order!.status == OrderStatus.toReceive ||
        order!.status == OrderStatus.completed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isConfirmed ? Icons.check_circle_rounded : (isPending ? Icons.hourglass_top_rounded : Icons.error_rounded),
          color: isConfirmed ? context.colors.success : (isPending ? context.colors.ink : context.colors.error),
          size: 72,
        ),
        const SizedBox(height: 20),
        Text(
          isConfirmed ? 'Order placed!' : (isPending ? 'Confirming payment…' : 'Payment failed'),
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isPending
              ? "We're waiting for your payment provider to confirm this order. This can take a few seconds."
              : (isConfirmed
                  ? 'Order #${order!.id.substring(0, 8).toUpperCase()} · ₱${order!.total.toStringAsFixed(2)}'
                  : 'Your payment could not be completed. No charge was made.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 28),
        if (!isPending)
          PrimaryButton(
            label: isConfirmed ? 'Continue shopping' : 'Try again',
            onPressed: () => isConfirmed ? context.go('/home') : context.pop(),
          ),
      ],
    );
  }
}
