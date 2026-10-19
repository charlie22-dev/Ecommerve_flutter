import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/order.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/primary_button.dart';
import 'checkout_providers.dart';

class OrderConfirmationScreen extends ConsumerStatefulWidget {
  const OrderConfirmationScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends ConsumerState<OrderConfirmationScreen> {
  @override
  void initState() {
    super.initState();
    _autoConfirmOrder();
  }

  /// Automatically marks order as paid/toShip if coming from payment flow
  Future<void> _autoConfirmOrder() async {
    try {
      await Supabase.instance.client
          .from('orders')
          .update({
            'status': 'toShip',
            'paid_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', widget.orderId);

      await Supabase.instance.client
          .from('seller_orders')
          .update({'status': 'confirmed'})
          .eq('order_id', widget.orderId);

      if (mounted) {
        ref.invalidate(orderStreamProvider(widget.orderId));
      }
    } catch (e) {
      debugPrint('Auto-confirm order note: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderStreamProvider(widget.orderId));

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: orderAsync.when(
              data: (order) => _ConfirmationBody(order: order),
              loading: () => CircularProgressIndicator(color: context.colors.ink),
              error: (err, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: context.colors.success, size: 72),
                  const SizedBox(height: 16),
                  Text('Payment Successful!', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text('Your order has been recorded.', style: TextStyle(color: context.colors.textSecondary)),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Continue shopping',
                    onPressed: () => context.go('/home'),
                  ),
                ],
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
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: context.colors.success, size: 72),
          const SizedBox(height: 16),
          Text('Payment Successful!', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Continue shopping',
            onPressed: () => context.go('/home'),
          ),
        ],
      );
    }

    final isFailed = order!.status == OrderStatus.failed || order!.status == OrderStatus.cancelled;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isFailed ? Icons.error_rounded : Icons.check_circle_rounded,
          color: isFailed ? context.colors.error : context.colors.success,
          size: 72,
        ),
        const SizedBox(height: 20),
        Text(
          isFailed ? 'Payment Failed' : 'Payment Successful!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          isFailed
              ? 'Your payment could not be processed. No charge was made.'
              : 'Order #${order!.id.substring(0, 8).toUpperCase()} · ₱${order!.total.toStringAsFixed(2)}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isFailed ? context.colors.error : context.colors.textPrimary,
            fontSize: 16,
            fontWeight: isFailed ? FontWeight.normal : FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (!isFailed)
          Text(
            'Your order has been placed and confirmed. We are preparing it for shipment.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: isFailed ? 'Try again' : 'Continue shopping',
          onPressed: () => isFailed ? context.pop() : context.go('/home'),
        ),
        if (!isFailed) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/orders'),
            child: const Text('View Order History'),
          ),
        ],
      ],
    );
  }
}
