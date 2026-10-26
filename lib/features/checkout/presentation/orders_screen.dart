import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/order.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../admin/presentation/admin_providers.dart';
import 'checkout_providers.dart';
import 'widgets/rate_order_sheet.dart';

enum OrderTab { toPay, toShip, toReceive, toRate, all }

extension OrderTabX on OrderTab {
  String get label => switch (this) {
        OrderTab.toPay => 'To Pay',
        OrderTab.toShip => 'To Ship',
        OrderTab.toReceive => 'To Receive',
        OrderTab.toRate => 'To Rate',
        OrderTab.all => 'All',
      };
}

final _ordersTabProvider = StateProvider<OrderTab>((ref) => OrderTab.toShip);

/// Order tracking now lives under the Me tab (see profile_screen.dart's
/// quick-access row) rather than its own bottom-nav tab — matches the
/// standard ecommerce "Me" screen pattern (Shopee/Lazada-style To Pay / To
/// Ship / To Receive / To Rate). `initialTab` lets the Me screen deep-link
/// straight into one segment.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key, this.initialTab});
  final OrderTab? initialTab;

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(_ordersTabProvider.notifier).state = widget.initialTab!;
      });
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(userOrdersProvider);
    await ref.read(userOrdersProvider.future).then((_) {}, onError: (_) {});
  }

  List<Order> _filter(List<Order> orders, OrderTab tab) {
    return switch (tab) {
      OrderTab.toPay => orders.where((o) => o.status == OrderStatus.pending).toList(),
      OrderTab.toShip => orders.where((o) => o.status == OrderStatus.toShip).toList(),
      OrderTab.toReceive => orders.where((o) => o.status == OrderStatus.toReceive).toList(),
      OrderTab.toRate => orders.where((o) => o.status == OrderStatus.completed && !o.rated).toList(),
      OrderTab.all => orders,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ordersAsync = ref.watch(userOrdersProvider);
    final selectedTab = ref.watch(_ordersTabProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: OrderTab.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final tab = OrderTab.values[i];
                final selected = tab == selectedTab;
                return ChoiceChip(
                  label: Text(tab.label),
                  selected: selected,
                  onSelected: (_) => ref.read(_ordersTabProvider.notifier).state = tab,
                  showCheckmark: false,
                  selectedColor: colors.ink,
                  backgroundColor: colors.surface,
                  side: BorderSide(color: selected ? colors.ink : colors.border),
                  labelStyle: TextStyle(
                    color: selected ? colors.onInk : colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                final filtered = _filter(orders, selectedTab);
                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      children: [
                        SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
                        EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No orders here',
                          message: selectedTab == OrderTab.toShip
                              ? 'Orders you place at checkout will show up here.'
                              : "You don't have any orders in this category yet.",
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _OrderTile(order: filtered[i]),
                  ),
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
              error: (err, _) => Center(child: Text('Could not load your orders.', style: TextStyle(color: colors.error))),
            ),
          ),
        ],
      ),
    );
  }
}

(String, Color) statusStyle(OrderStatus status, AppColorTokens colors) {
  final color = switch (status) {
    OrderStatus.pending => colors.info,
    OrderStatus.toShip => colors.accentBlue,
    OrderStatus.toReceive => colors.star,
    OrderStatus.completed => colors.success,
    OrderStatus.cancelled => colors.textTertiary,
    OrderStatus.failed => colors.error,
  };
  return (status.label, color);
}

class _OrderTile extends ConsumerWidget {
  const _OrderTile({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isAdmin = ref.watch(isAdminProvider);
    final (label, color) = statusStyle(order.status, colors);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/orders/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.id.substring(0, 8).toUpperCase()}',
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (order.createdAt != null)
              Text(DateFormat.yMMMd().add_jm().format(order.createdAt!), style: TextStyle(color: colors.textTertiary, fontSize: 12)),
            const SizedBox(height: 10),
            ...order.items.take(3).map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${item.title} ×${item.quantity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textSecondary, fontSize: 13),
                    ),
                  ),
                ),
            if (order.items.length > 3)
              Text('+ ${order.items.length - 3} more', style: TextStyle(color: colors.textTertiary, fontSize: 12)),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text('${order.paymentMethodLabel} · ${order.paymentStatusLabel}',
                  style: TextStyle(color: order.isPaid ? colors.success : colors.textSecondary, fontSize: 13))),
                Text(
                  '₱${order.total.toStringAsFixed(2)}',
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ],
            ),
            if (order.status == OrderStatus.completed && !order.rated) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => RateOrderSheet.show(context, order),
                icon: const Icon(Icons.star_outline_rounded, size: 16),
                label: const Text('Rate this order'),
              ),
            ],
            if (isAdmin && (order.status == OrderStatus.toShip || order.status == OrderStatus.toReceive)) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref.read(orderRepositoryProvider).updateStatus(
                      order.id,
                      order.status == OrderStatus.toShip ? OrderStatus.toReceive : OrderStatus.completed,
                    ),
                icon: Icon(
                  order.status == OrderStatus.toShip ? Icons.local_shipping_outlined : Icons.task_alt_rounded,
                  size: 16,
                ),
                label: Text(
                  order.status == OrderStatus.toShip ? 'Mark as dispatched (admin)' : 'Mark as delivered (admin)',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
