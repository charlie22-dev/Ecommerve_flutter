import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/order.dart';
import 'checkout_providers.dart';

/// Reading a receipt never changes payment status.
class OrderConfirmationScreen extends ConsumerWidget {
  const OrderConfirmationScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order status'),
        leading: BackButton(onPressed: () => context.go('/home')),
      ),
      body: Center(
        child: ref
            .watch(orderStreamProvider(orderId))
            .when(
              loading: () => const CircularProgressIndicator(),
              error: (_, _) => const Text(
                'Could not load your order. Please check My Orders.',
              ),
              data: (order) {
                final paid = order?.isPaid ?? false;
                final message = order == null
                    ? 'Order not found.'
                    : order.paymentStatus == 'requires_review'
                    ? 'Payment received. Please contact support to review this order.'
                    : order.status == OrderStatus.failed ||
                          order.status == OrderStatus.cancelled
                    ? 'Payment was not completed.'
                    : order.paymentMethod == PaymentMethod.cashOnDelivery
                    ? 'Order placed. Pay on delivery.'
                    : paid
                    ? 'Payment confirmed.'
                    : 'Awaiting payment confirmation.';
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => context.go('/orders/$orderId'),
                      child: const Text('View Order'),
                    ),
                  ],
                );
              },
            ),
      ),
    );
  }
}
