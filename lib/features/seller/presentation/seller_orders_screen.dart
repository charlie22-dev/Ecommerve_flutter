import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/seller_order.dart';
import '../../../core/services/db.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/text_prompt_dialog.dart';
import 'seller_providers.dart';

/// This store's part of each customer order. Sellers see only their own
/// items and the delivery address — never the rest of the buyer's order.
class SellerOrdersScreen extends ConsumerStatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  ConsumerState<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

enum _Filter {
  toFulfill('To fulfill'),
  shipped('Shipped'),
  delivered('Delivered'),
  cancelled('Cancelled'),
  all('All');

  const _Filter(this.label);
  final String label;

  bool matches(SellerOrder o) => switch (this) {
        _Filter.toFulfill => o.status.needsAction,
        _Filter.shipped => o.status == SellerOrderStatus.shipped,
        _Filter.delivered => o.status == SellerOrderStatus.delivered,
        _Filter.cancelled => o.status == SellerOrderStatus.cancelled || o.status == SellerOrderStatus.refunded,
        _Filter.all => true,
      };
}

class _SellerOrdersScreenState extends ConsumerState<SellerOrdersScreen> {
  _Filter _filter = _Filter.toFulfill;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ordersAsync = ref.watch(myStoreOrdersProvider);
    final all = ordersAsync.value ?? const <SellerOrder>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Store Orders')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              itemCount: _Filter.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = _Filter.values[i];
                final selected = f == _filter;
                return ChoiceChip(
                  label: Text('${f.label} (${all.where(f.matches).length})'),
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
                final shown = orders.where(_filter.matches).toList();
                if (shown.isEmpty) {
                  return const EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders here');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _SellerOrderCard(order: shown[i]),
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

(String, Color) sellerOrderStatusStyle(SellerOrderStatus s, AppColorTokens colors) => switch (s) {
      SellerOrderStatus.pending => (s.label, colors.accentBlue),
      SellerOrderStatus.confirmed || SellerOrderStatus.processing => (s.label, colors.accentOrange),
      SellerOrderStatus.shipped => (s.label, colors.star),
      SellerOrderStatus.delivered => (s.label, colors.success),
      SellerOrderStatus.cancelled || SellerOrderStatus.refunded => (s.label, colors.textTertiary),
    };

class _SellerOrderCard extends ConsumerStatefulWidget {
  const _SellerOrderCard({required this.order});
  final SellerOrder order;

  @override
  ConsumerState<_SellerOrderCard> createState() => _SellerOrderCardState();
}

class _SellerOrderCardState extends ConsumerState<_SellerOrderCard> {
  bool _busy = false;

  Future<void> _advance(SellerOrderStatus status) async {
    String? carrier;
    String? tracking;
    if (status == SellerOrderStatus.shipped) {
      final values = await showTextPromptDialog(
        context,
        title: 'Ship order #${widget.order.shortOrderId}',
        message: 'The customer sees the courier and tracking number.',
        fields: const ['Courier (e.g. J&T Express)', 'Tracking number'],
        confirmLabel: 'Mark shipped',
      );
      if (values == null) return;
      (carrier, tracking) = (values[0], values[1]);
    }

    setState(() => _busy = true);
    try {
      await ref.read(sellerRepositoryProvider).updateOrder(
            widget.order.id,
            status,
            carrier: carrier,
            tracking: tracking,
          );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final order = widget.order;
    final (label, color) = sellerOrderStatusStyle(order.status, colors);
    final address = order.shippingAddress;

    final actions = <Widget>[
      if (order.status == SellerOrderStatus.pending)
        _ActionButton(label: 'Confirm', icon: Icons.check_circle_outline, onTap: () => _advance(SellerOrderStatus.confirmed)),
      if (order.status.needsAction)
        _ActionButton(label: 'Ship', icon: Icons.local_shipping_outlined, onTap: () => _advance(SellerOrderStatus.shipped)),
      if (order.status == SellerOrderStatus.shipped)
        _ActionButton(label: 'Mark delivered', icon: Icons.task_alt_rounded, onTap: () => _advance(SellerOrderStatus.delivered)),
    ];

    return Container(
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
                  '#${order.shortOrderId}',
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              StatusChip(label: label, color: color),
            ],
          ),
          if (order.createdAt != null)
            Text(
              DateFormat.MMMd().add_jm().format(order.createdAt!),
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            ),
          const SizedBox(height: 8),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.title} ×${item.quantity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textPrimary, fontSize: 13),
                    ),
                  ),
                  Text('₱${item.lineTotal.toStringAsFixed(2)}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          if (address != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_outlined, size: 15, color: colors.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${address.recipientName} · ${address.phoneNumber}\n${address.fullAddress}',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          if (order.trackingNumber != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.local_shipping_outlined, size: 15, color: colors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  '${order.trackingCarrier} · ${order.trackingNumber}',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Commission −₱${order.commissionTotal.toStringAsFixed(2)}',
                  style: TextStyle(color: colors.textTertiary, fontSize: 12),
                ),
              ),
              Text(
                'You earn ₱${order.earnings.toStringAsFixed(2)}',
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
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
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.textPrimary;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(side: BorderSide(color: context.colors.border)),
    );
  }
}
