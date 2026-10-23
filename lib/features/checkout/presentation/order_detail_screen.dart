import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/order.dart';
import '../../../core/models/seller_order.dart';
import '../../../core/models/shipping_option.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../admin/presentation/admin_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../seller/presentation/seller_providers.dart';
import 'checkout_providers.dart';
import 'orders_screen.dart';
import 'widgets/rate_order_sheet.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final orderAsync = ref.watch(orderStreamProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return Center(child: Text('Order not found.', style: TextStyle(color: colors.textSecondary)));
          }
          return _OrderDetailBody(order: order);
        },
        loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
        error: (err, _) => Center(child: Text('Could not load this order.', style: TextStyle(color: colors.error))),
      ),
    );
  }
}

class _OrderDetailBody extends ConsumerWidget {
  const _OrderDetailBody({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isAdmin = ref.watch(isAdminProvider);
    // Admins can open any customer's order; only the buyer may review it.
    final isBuyer = ref.watch(authStateProvider).value?.uid == order.uid;
    final (label, color) = statusStyle(order.status, colors);
    final shipping = ShippingOption.fromId(order.shippingOptionId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Order #${order.id.substring(0, 8).toUpperCase()}',
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        if (order.createdAt != null) ...[
          const SizedBox(height: 4),
          Text(DateFormat.yMMMd().add_jm().format(order.createdAt!), style: TextStyle(color: colors.textTertiary, fontSize: 12)),
        ],
        const SizedBox(height: 20),
        _SectionCard(
          title: 'Items',
          child: Column(
            children: [
              for (final item in order.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 44, height: 66, child: BookCoverImage(url: item.coverUrl, borderRadius: 8)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('×${item.quantity}', style: TextStyle(color: colors.textTertiary, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text('₱${item.lineTotal.toStringAsFixed(2)}', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        _Shipments(orderId: order.id),
        if (order.shippingAddress != null) ...[
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Shipping Address',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.shippingAddress!.label} · ${order.shippingAddress!.recipientName}',
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(order.shippingAddress!.phoneNumber, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(order.shippingAddress!.fullAddress, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Shipping & Payment',
          child: Column(
            children: [
              _Row('Shipping method', '${shipping.label} (${shipping.eta})'),
              _Row('Payment method', order.paymentMethod.label),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Order Total',
          child: Column(
            children: [
              _Row('Subtotal', '₱${order.subtotal.toStringAsFixed(2)}'),
              _Row('Shipping', order.shippingCost == 0 ? 'Free' : '₱${order.shippingCost.toStringAsFixed(2)}'),
              if (order.voucherCode != null)
                _Row('Voucher (${order.voucherCode})', '−₱${order.voucherDiscount.toStringAsFixed(2)}', valueColor: colors.success),
              const Divider(height: 20),
              _Row('Total Payment', '₱${order.total.toStringAsFixed(2)}', emphasize: true),
            ],
          ),
        ),
        if (isBuyer && order.status == OrderStatus.completed && !order.rated) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => RateOrderSheet.show(context, order),
            icon: const Icon(Icons.star_outline_rounded, size: 18),
            label: const Text('Rate this order'),
          ),
        ],
        if (isAdmin && (order.status == OrderStatus.toShip || order.status == OrderStatus.toReceive)) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => ref.read(orderRepositoryProvider).updateStatus(
                  order.id,
                  order.status == OrderStatus.toShip ? OrderStatus.toReceive : OrderStatus.completed,
                ),
            icon: Icon(order.status == OrderStatus.toShip ? Icons.local_shipping_outlined : Icons.task_alt_rounded, size: 18),
            label: Text(order.status == OrderStatus.toShip ? 'Mark as dispatched (admin)' : 'Mark as delivered (admin)'),
          ),
        ],
      ],
    );
  }
}

/// Each store ships its own part of the order — show who's sending what,
/// with the courier and tracking number once it's on its way.
class _Shipments extends ConsumerWidget {
  const _Shipments({required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shipments = ref.watch(orderShipmentsProvider(orderId)).value ?? const <SellerOrder>[];
    if (shipments.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: _SectionCard(
        title: shipments.length == 1 ? 'Shipment' : 'Shipments (${shipments.length} stores)',
        child: Column(
          children: [
            for (final s in shipments) _ShipmentRow(shipment: s),
          ],
        ),
      ),
    );
  }
}

class _ShipmentRow extends ConsumerWidget {
  const _ShipmentRow({required this.shipment});
  final SellerOrder shipment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final storeAsync = ref.watch(storeByIdProvider(shipment.storeId));
    final store = storeAsync.value;
    final currentUid = ref.watch(authStateProvider).value?.uid;
    final isOwner = store != null && store.ownerId != null && store.ownerId == currentUid;
    final canMessage = store != null && store.isActive && !isOwner;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.storefront_outlined, size: 18, color: colors.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shipment.storeName ?? store?.name ?? 'Store',
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                if (shipment.trackingNumber != null)
                  Text(
                    '${shipment.trackingCarrier} · ${shipment.trackingNumber}',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (canMessage)
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                final path = store.isOfficial
                    ? '/messages/store'
                    : '/messages/seller/${shipment.storeId}?name=${Uri.encodeComponent(shipment.storeName ?? store.name)}';
                context.push(path);
              },
              icon: Icon(Icons.chat_bubble_outline_rounded, size: 14, color: colors.ink),
              label: Text('Message', style: TextStyle(color: colors.ink, fontSize: 12, fontWeight: FontWeight.w700)),
            )
          else if (isOwner)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.ink.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Your store', style: TextStyle(color: colors.ink, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(width: 8),
          Text(shipment.status.label, style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.valueColor, this.emphasize = false});
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // A long value (e.g. "Standard Shipping (3-5 business days)") used to
    // overflow off the right edge since neither Text here was constrained
    // — `Flexible` lets it wrap to a second line instead.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colors.textSecondary, fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500, fontSize: emphasize ? 15 : 13)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? (emphasize ? colors.ink : colors.textPrimary),
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                fontSize: emphasize ? 18 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
