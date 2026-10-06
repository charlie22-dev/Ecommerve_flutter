import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/order.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../data/admin_repository.dart';
import 'admin_providers.dart';

/// Admin home: store overview numbers plus the entry points to manage
/// products, orders, vouchers and customer messages.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final stats = ref.watch(adminStatsProvider).value;
    final threads = ref.watch(adminThreadsProvider).value ?? const [];
    final unanswered = threads.where((t) => t.needsReply).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoute.adminAddProduct),
        backgroundColor: colors.ink,
        foregroundColor: colors.onInk,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminStatsProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          children: [
            Text('Overview', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.7,
              children: [
                _StatTile(
                  label: 'Sales (completed)',
                  value: stats == null ? '—' : '₱${stats.revenue.toStringAsFixed(2)}',
                  icon: Icons.payments_outlined,
                  color: colors.success,
                ),
                _StatTile(
                  label: 'To ship',
                  value: stats == null ? '—' : '${stats.count(OrderStatus.toShip)}',
                  icon: Icons.inventory_2_outlined,
                  color: colors.accentBlue,
                  highlight: (stats?.count(OrderStatus.toShip) ?? 0) > 0,
                  onTap: () => context.push(AppRoute.adminOrders, extra: OrderStatus.toShip),
                ),
                _StatTile(
                  label: 'Products',
                  value: stats == null ? '—' : '${stats.productCount}',
                  icon: Icons.menu_book_outlined,
                  color: colors.ink,
                  onTap: () => context.push(AppRoute.adminProducts),
                ),
                _StatTile(
                  label: 'Low stock (≤${AdminRepository.lowStockThreshold})',
                  value: stats == null ? '—' : '${stats.lowStockCount}',
                  icon: Icons.warning_amber_rounded,
                  color: colors.accentOrange,
                  highlight: (stats?.lowStockCount ?? 0) > 0,
                  onTap: () => context.push(AppRoute.adminProducts),
                ),
                _StatTile(
                  label: 'In transit',
                  value: stats == null ? '—' : '${stats.count(OrderStatus.toReceive)}',
                  icon: Icons.local_shipping_outlined,
                  color: colors.star,
                  onTap: () => context.push(AppRoute.adminOrders, extra: OrderStatus.toReceive),
                ),
                _StatTile(
                  label: 'Customers',
                  value: stats == null ? '—' : '${stats.customerCount}',
                  icon: Icons.people_outline_rounded,
                  color: colors.info,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text('Manage', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _NavRow(
              icon: Icons.menu_book_outlined,
              title: 'Products',
              subtitle: 'Add, edit, restock and remove products',
              onTap: () => context.push(AppRoute.adminProducts),
            ),
            _NavRow(
              icon: Icons.receipt_long_outlined,
              title: 'Orders',
              subtitle: 'Every customer order — ship, deliver or cancel',
              onTap: () => context.push(AppRoute.adminOrders),
            ),
            _NavRow(
              icon: Icons.confirmation_number_outlined,
              title: 'Vouchers',
              subtitle: 'Create and manage discount codes',
              onTap: () => context.push(AppRoute.adminVouchers),
            ),
            _NavRow(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Customer messages',
              subtitle: unanswered == 0 ? 'Reply to customers as BookVerse Store' : '$unanswered waiting for a reply',
              badge: unanswered,
              onTap: () => context.push(AppRoute.adminMessages),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.highlight = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: highlight ? color : colors.border, width: highlight ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.title, required this.subtitle, required this.onTap, this.badge = 0});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: colors.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: colors.textPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: colors.textTertiary, fontSize: 12)),
                    ],
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: colors.error, borderRadius: BorderRadius.circular(10)),
                    child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
