import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/order.dart';
import '../../../core/services/db.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../../checkout/presentation/checkout_providers.dart';
import '../../checkout/presentation/orders_screen.dart' show statusStyle;
import '../data/admin_repository.dart';
import 'admin_providers.dart';
import 'admin_shell.dart';
import 'widgets/admin_table.dart';

/// Every customer's orders (the shopper Orders screen only shows your own),
/// filterable by status and searchable, with the fulfilment actions inline.
/// A table on wide screens, cards on phones.
class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key, this.initialStatus});

  final OrderStatus? initialStatus;

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  late OrderStatus? _filter = widget.initialStatus;
  String _query = '';

  static const _filters = <OrderStatus?>[
    null,
    OrderStatus.pending,
    OrderStatus.toShip,
    OrderStatus.toReceive,
    OrderStatus.completed,
    OrderStatus.cancelled,
  ];

  bool _matchesQuery(AdminOrder o) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final c = o.customer;
    return o.order.id.toLowerCase().startsWith(q.replaceAll('#', '')) ||
        (c?.name.toLowerCase().contains(q) ?? false) ||
        (c?.email.toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final wide = AdminShell.isWide(context);
    final ordersAsync = ref.watch(adminOrdersProvider);
    final all = (ordersAsync.value ?? const <AdminOrder>[]).where(_matchesQuery).toList();
    final pad = wide ? 28.0 : 20.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 4, pad, 4),
            child: AdminSearchField(
              hint: 'Search order #, customer name or email',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 6),
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
              data: (_) {
                final shown = _filter == null ? all : all.where((o) => o.order.status == _filter).toList();
                if (shown.isEmpty) {
                  return const EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders here');
                }
                if (wide) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(pad, 8, pad, 32),
                    child: _OrdersTable(orders: shown),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(pad, 8, pad, 32),
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

String _shortId(Order o) => '#${o.id.substring(0, 8).toUpperCase()}';

class _OrdersTable extends StatelessWidget {
  const _OrdersTable({required this.orders});
  final List<AdminOrder> orders;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AdminTable(
      columns: const [
        DataColumn(label: Text('ORDER')),
        DataColumn(label: Text('CUSTOMER')),
        DataColumn(label: Text('ITEMS')),
        DataColumn(label: Text('PAYMENT')),
        DataColumn(label: Text('TOTAL'), numeric: true),
        DataColumn(label: Text('STATUS')),
        DataColumn(label: Text('ACTIONS')),
      ],
      rows: [
        for (final entry in orders)
          () {
            final o = entry.order;
            final c = entry.customer;
            final (label, color) = statusStyle(o.status, colors);
            final itemCount = o.items.fold<int>(0, (n, i) => n + i.quantity);
            return adminRow(
              context,
              onTap: () => context.push('/orders/${o.id}'),
              cells: [
                DataCell(TwoLineCell(
                  _shortId(o),
                  o.createdAt == null ? '' : DateFormat.MMMd().add_jm().format(o.createdAt!),
                )),
                DataCell(TwoLineCell(
                  c?.label ?? 'Unknown customer',
                  c?.email ?? '',
                  leading: InitialAvatar(c?.label ?? '?'),
                )),
                DataCell(TwoLineCell(
                  '$itemCount item${itemCount == 1 ? '' : 's'}',
                  o.items.map((i) => i.title).join(', '),
                )),
                DataCell(Text(o.paymentMethod.label)),
                DataCell(Text('₱${o.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800))),
                DataCell(StatusChip(label: label, color: color)),
                DataCell(_OrderActions(order: o, compact: true)),
              ],
            );
          }(),
      ],
    );
  }
}

class _AdminOrderCard extends StatelessWidget {
  const _AdminOrderCard({required this.entry});
  final AdminOrder entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final order = entry.order;
    final customer = entry.customer;
    final (label, color) = statusStyle(order.status, colors);
    final itemCount = order.items.fold<int>(0, (n, i) => n + i.quantity);

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
                    _shortId(order),
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                StatusChip(label: label, color: color),
              ],
            ),
            const SizedBox(height: 8),
            TwoLineCell(
              customer?.label ?? 'Unknown customer',
              customer?.email ?? '',
              leading: InitialAvatar(customer?.label ?? '?'),
            ),
            if (order.shippingAddress != null) ...[
              const SizedBox(height: 6),
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
            const SizedBox(height: 10),
            _OrderActions(order: order),
          ],
        ),
      ),
    );
  }
}

/// The next fulfilment steps for an order — full buttons on cards, icon
/// buttons in the table. Shared so both layouts behave identically.
class _OrderActions extends ConsumerStatefulWidget {
  const _OrderActions({required this.order, this.compact = false});
  final Order order;
  final bool compact;

  @override
  ConsumerState<_OrderActions> createState() => _OrderActionsState();
}

class _OrderActionsState extends ConsumerState<_OrderActions> {
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
      await ref.read(orderRepositoryProvider).updateStatus(widget.order.id, status);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update the order: ${errorMessage(e)}')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final status = widget.order.status;
    final actions = [
      if (status == OrderStatus.pending)
        (Icons.check_circle_outline, 'Mark as paid', false, () => _setStatus(OrderStatus.toShip)),
      if (status == OrderStatus.toShip)
        (Icons.local_shipping_outlined, 'Mark dispatched', false, () => _setStatus(OrderStatus.toReceive)),
      if (status == OrderStatus.toReceive)
        (Icons.task_alt_rounded, 'Mark delivered', false, () => _setStatus(OrderStatus.completed)),
      if (status == OrderStatus.pending || status == OrderStatus.toShip)
        (Icons.close_rounded, 'Cancel', true, () => _setStatus(OrderStatus.cancelled, confirm: true)),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();
    if (_busy) {
      return SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: colors.ink));
    }

    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (icon, label, destructive, onTap) in actions)
            IconButton(
              tooltip: label,
              onPressed: onTap,
              icon: Icon(icon, size: 20, color: destructive ? colors.error : colors.textPrimary),
            ),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, label, destructive, onTap) in actions)
          OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16, color: destructive ? colors.error : colors.textPrimary),
            label: Text(label, style: TextStyle(color: destructive ? colors.error : colors.textPrimary)),
            style: OutlinedButton.styleFrom(side: BorderSide(color: destructive ? colors.error : colors.border)),
          ),
      ],
    );
  }
}
