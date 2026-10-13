import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/order.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/dashboard_tiles.dart';
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
    final pendingSellers =
        (ref.watch(adminApplicationsProvider).value ?? const []).where((a) => a.status == 'pending').length;
    final listingsInReview = ref.watch(adminListingReviewProvider).value?.length ?? 0;

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
                StatTile(
                  label: 'Sales (completed)',
                  value: stats == null ? '—' : '₱${stats.revenue.toStringAsFixed(2)}',
                  icon: Icons.payments_outlined,
                  color: colors.success,
                ),
                StatTile(
                  label: 'To ship',
                  value: stats == null ? '—' : '${stats.count(OrderStatus.toShip)}',
                  icon: Icons.inventory_2_outlined,
                  color: colors.accentBlue,
                  highlight: (stats?.count(OrderStatus.toShip) ?? 0) > 0,
                  onTap: () => context.push(AppRoute.adminOrders, extra: OrderStatus.toShip),
                ),
                StatTile(
                  label: 'Products',
                  value: stats == null ? '—' : '${stats.productCount}',
                  icon: Icons.menu_book_outlined,
                  color: colors.ink,
                  onTap: () => context.push(AppRoute.adminProducts),
                ),
                StatTile(
                  label: 'Low stock (≤${AdminRepository.lowStockThreshold})',
                  value: stats == null ? '—' : '${stats.lowStockCount}',
                  icon: Icons.warning_amber_rounded,
                  color: colors.accentOrange,
                  highlight: (stats?.lowStockCount ?? 0) > 0,
                  onTap: () => context.push(AppRoute.adminProducts),
                ),
                StatTile(
                  label: 'In transit',
                  value: stats == null ? '—' : '${stats.count(OrderStatus.toReceive)}',
                  icon: Icons.local_shipping_outlined,
                  color: colors.star,
                  onTap: () => context.push(AppRoute.adminOrders, extra: OrderStatus.toReceive),
                ),
                StatTile(
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
            DashboardNavRow(
              icon: Icons.menu_book_outlined,
              title: 'Products',
              subtitle: 'Add, edit, restock and remove products',
              onTap: () => context.push(AppRoute.adminProducts),
            ),
            DashboardNavRow(
              icon: Icons.receipt_long_outlined,
              title: 'Orders',
              subtitle: 'Every customer order — ship, deliver or cancel',
              onTap: () => context.push(AppRoute.adminOrders),
            ),
            DashboardNavRow(
              icon: Icons.storefront_outlined,
              title: 'Sellers',
              subtitle: pendingSellers == 0
                  ? 'Review applications, suspend or reinstate stores'
                  : '$pendingSellers application${pendingSellers == 1 ? '' : 's'} to review',
              badge: pendingSellers,
              onTap: () => context.push(AppRoute.adminSellers),
            ),
            DashboardNavRow(
              icon: Icons.fact_check_outlined,
              title: 'Listing review',
              subtitle: listingsInReview == 0
                  ? "Approve or reject sellers' new listings"
                  : '$listingsInReview listing${listingsInReview == 1 ? '' : 's'} waiting',
              badge: listingsInReview,
              onTap: () => context.push(AppRoute.adminListings),
            ),
            DashboardNavRow(
              icon: Icons.confirmation_number_outlined,
              title: 'Vouchers',
              subtitle: 'Create and manage discount codes',
              onTap: () => context.push(AppRoute.adminVouchers),
            ),
            DashboardNavRow(
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
