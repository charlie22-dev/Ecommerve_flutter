import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/order.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../checkout/presentation/checkout_providers.dart';
import '../../checkout/presentation/orders_screen.dart' show statusStyle;
import '../data/admin_repository.dart';
import 'admin_providers.dart';

/// Every customer's orders (the shopper Orders screen only shows your own),
/// filterable by status, with the fulfilment actions inline.
class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key, this.initialStatus});

  final OrderStatus? initialStatus;

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  late OrderStatus? _filter = widget.initialStatus;

  static const _filters = <OrderStatus?>[
    null,
    OrderStatus.pending,
    OrderStatus.toShip,
    OrderStatus.toReceive,
    OrderStatus.completed,
    OrderStatus.cancelled,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ordersAsync = ref.watch(adminOrdersProvider);
    final all = ordersAsync.value ?? const <AdminOrder>[];

    return Scaffold(
      appBar: AppBar(title: const Text('All Orders')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = _filters[i];
                final count = f == null ? all.length : all.where((o) => o.order.status == f).length;
                final selected = f == _filter;
                return ChoiceChip(
                  label: Text('${f?.label ?? 'All'} ($count)'),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = f),
                  selectedColor: colors.ink,
                  labelStyle: TextStyle(color: selected ? colors.onInk : colors.textPrimary, fontWeight: FontWeight.w600),
                  backgroundColor: colors.surface,
                  side: BorderSide(color: selected ? colors.ink : colors.border),
                  shape: const StadiumBorder(),
                  showCheckmark: false,
                );
              },
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                final shown = _filter == null ? orders : orders.where((o) => o.order.status == _filter).toList();
                if (shown.isEmpty) {
                  return const EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders here');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _AdminOrderCard(entry: shown[i]),
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
              error: (e, _) => Center(child: Text('Could not load orders.\n$e', textAlign: TextAlign.center)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminOrderCard extends ConsumerStatefulWidget {
  const _AdminOrderCard({required this.entry});
  final AdminOrder entry;

  @override
  ConsumerState<_AdminOrderCard> createState() => _AdminOrderCardState();
}

class _AdminOrderCardState extends ConsumerState<_AdminOrderCard> {
  bool _busy = false;

  Future<void> _setStatus(OrderStatus status, {bool confirm = false}) async {
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel this order?'),
          content: const Text('The customer is notified and the items go back into stock.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep order')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Cancel order', style: TextStyle(color: context.colors.error)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(orderRepositoryProvider).updateStatus(widget.entry.order.id, status);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update the order: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final order = widget.entry.order;
    final customer = widget.entry.customer;
    final (label, color) = statusStyle(order.status, colors);
    final itemCount = order.items.fold<int>(0, (n, i) => n + i.quantity);

    final actions = <Widget>[
      if (order.status == OrderStatus.pending)
        _ActionButton(label: 'Mark as paid', icon: Icons.check_circle_outline, onTap: () => _setStatus(OrderStatus.toShip)),
      if (order.status == OrderStatus.toShip)
        _ActionButton(label: 'Mark dispatched', icon: Icons.local_shipping_outlined, onTap: () => _setStatus(OrderStatus.toReceive)),
      if (order.status == OrderStatus.toReceive)
        _ActionButton(label: 'Mark delivered', icon: Icons.task_alt_rounded, onTap: () => _setStatus(OrderStatus.completed)),
      if (order.status == OrderStatus.pending || order.status == OrderStatus.toShip)
        _ActionButton(
          label: 'Cancel',
          icon: Icons.close_rounded,
          destructive: true,
          onTap: () => _setStatus(OrderStatus.cancelled, confirm: true),
        ),
    ];

    return InkWell(
      onTap: () => context.push('/orders/${order.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${order.id.substring(0, 8).toUpperCase()}',
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 15, color: colors.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    customer == null ? 'Unknown customer' : '${customer.label}  ·  ${customer.email}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
            if (order.shippingAddress != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 15, color: colors.textTertiary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${order.shippingAddress!.recipientName} · ${order.shippingAddress!.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              order.items.map((i) => '${i.title} ×${i.quantity}').join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textPrimary, fontSize: 13),
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${order.createdAt == null ? '' : DateFormat.MMMd().add_jm().format(order.createdAt!)}'
                    '  ·  $itemCount item${itemCount == 1 ? '' : 's'}  ·  ${order.paymentMethod.label}',
                    style: TextStyle(color: colors.textTertiary, fontSize: 12),
                  ),
                ),
                Text(
                  '₱${order.total.toStringAsFixed(2)}',
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              _busy
                  ? Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: colors.ink)))
                  : Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.onTap, this.destructive = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? context.colors.error : context.colors.textPrimary;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(side: BorderSide(color: destructive ? context.colors.error : context.colors.border)),
    );
  }
}
