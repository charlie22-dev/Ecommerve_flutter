import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/pending_return_location.dart';
import '../../../core/dev/dev_preview.dart';
import '../../../core/models/book.dart';
import '../../../core/models/order.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/dashboard_tiles.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/admin_repository.dart';
import 'admin_providers.dart';
import 'admin_shell.dart';

String _peso(double v) => '₱${NumberFormat('#,##0.00').format(v)}';
String _pesoShort(double v) => '₱${NumberFormat.compact().format(v)}';

/// Admin home, Shopee Seller Centre–style: what needs doing now, then how
/// the marketplace is doing over the chosen period.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final wide = AdminShell.isWide(context);
    final dash = ref.watch(adminDashboardProvider).value;

    const todo = _TodoCard();
    final chart = _Card(
      title: dash == null || dash.days <= 31 ? 'Sales per day' : 'Sales per week',
      trailing: dash == null ? null : _peso(dash.grossSales),
      child: dash == null ? const _Loading() : _SalesChart(dash: dash),
    );
    final categories = _Card(
      title: 'Top categories',
      child: dash == null ? const _Loading() : _Categories(dash: dash),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: !wide,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoute.adminAddProduct),
        backgroundColor: colors.ink,
        foregroundColor: colors.onInk,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminDashboardProvider),
        child: ListView(
          padding: EdgeInsets.fromLTRB(wide ? 28 : 20, 8, wide ? 28 : 20, 96),
          children: [
            const _PeriodPicker(),
            const SizedBox(height: 16),
            _Kpis(dash: dash, columns: wide ? 3 : 2),
            const SizedBox(height: 20),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: Column(children: [chart, const SizedBox(height: 20), categories])),
                  const SizedBox(width: 20),
                  const Expanded(flex: 2, child: todo),
                ],
              )
            else ...[
              todo,
              const SizedBox(height: 20),
              chart,
              const SizedBox(height: 20),
              categories,
              const SizedBox(height: 28),
              const _MobileMenu(),
            ],
          ],
        ),
      ),
    );
  }
}

class _PeriodPicker extends ConsumerWidget {
  const _PeriodPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final days = ref.watch(adminDashboardDaysProvider);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final d in const [7, 30, 90])
          ChoiceChip(
            label: Text('Last $d days'),
            selected: d == days,
            onSelected: (_) => ref.read(adminDashboardDaysProvider.notifier).state = d,
            selectedColor: colors.ink,
            labelStyle: TextStyle(color: d == days ? colors.onInk : colors.textPrimary, fontWeight: FontWeight.w600),
            backgroundColor: colors.surface,
            side: BorderSide(color: d == days ? colors.ink : colors.border),
            shape: const StadiumBorder(),
            showCheckmark: false,
          ),
      ],
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.dash, required this.columns});
  final AdminDashboard? dash;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final d = dash;
    String v(String Function(AdminDashboard d) f) => d == null ? '—' : f(d);
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: columns == 3 ? 2.4 : 1.7,
      children: [
        StatTile(
          label: 'Gross sales',
          value: v((d) => _peso(d.grossSales)),
          icon: Icons.payments_outlined,
          color: colors.success,
        ),
        StatTile(
          label: 'Orders',
          value: v((d) => '${d.orderCount}'),
          icon: Icons.receipt_long_outlined,
          color: colors.accentBlue,
          onTap: () => context.push(AppRoute.adminOrders),
        ),
        StatTile(
          label: 'Avg. order value',
          value: v((d) => _peso(d.averageOrder)),
          icon: Icons.shopping_bag_outlined,
          color: colors.info,
        ),
        StatTile(
          label: 'Commission earned',
          value: v((d) => _peso(d.commission)),
          icon: Icons.percent_rounded,
          color: colors.star,
        ),
        StatTile(
          label: 'Customers',
          value: v((d) => '${d.customerCount}'),
          icon: Icons.people_outline_rounded,
          color: colors.ink,
        ),
        StatTile(
          label: 'Active sellers',
          value: v((d) => '${d.activeSellers}'),
          icon: Icons.storefront_outlined,
          color: colors.accentOrange,
          onTap: () => context.push(AppRoute.adminSellers),
        ),
      ],
    );
  }
}

class _TodoCard extends ConsumerWidget {
  const _TodoCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final todo = ref.watch(adminTodoProvider);
    final rows = <(IconData, String, int, VoidCallback)>[
      (Icons.inventory_2_outlined, 'Orders to ship', todo.toShip,
          () => context.push(AppRoute.adminOrders, extra: OrderStatus.toShip)),
      (Icons.storefront_outlined, 'Seller applications', todo.sellerApplications,
          () => context.push(AppRoute.adminSellers)),
      (Icons.fact_check_outlined, 'Listings to review', todo.listingsToReview,
          () => context.push(AppRoute.adminListings)),
      (Icons.chat_bubble_outline_rounded, 'Unanswered messages', todo.unansweredMessages,
          () => context.push(AppRoute.adminMessages)),
      (Icons.warning_amber_rounded, 'Low stock (≤${AdminRepository.lowStockThreshold})', todo.lowStock,
          () => context.push(AppRoute.adminProducts)),
    ];
    final allClear = rows.every((r) => r.$3 == 0);

    return _Card(
      title: 'To do',
      child: Column(
        children: [
          if (allClear)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: colors.success, size: 20),
                  const SizedBox(width: 10),
                  Text('All caught up', style: TextStyle(color: colors.textSecondary)),
                ],
              ),
            ),
          for (final (icon, label, count, onTap) in rows)
            if (count > 0)
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: colors.textPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(label, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                      ),
                      Text('$count',
                          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                      Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// One series, so no legend: the card title names it. Bars use the theme's
/// ink; hover (or long-press) a bar for its exact value.
class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.dash});
  final AdminDashboard dash;

  static const _height = 160.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final buckets = dash.sales;
    final max = buckets.fold<double>(0, (m, b) => b.amount > m ? b.amount : m);
    if (max == 0) {
      return SizedBox(
        height: _height,
        child: Center(child: Text('No sales in this period yet', style: TextStyle(color: colors.textTertiary))),
      );
    }
    final weekly = dash.days > 31;
    final dateFormat = DateFormat.MMMd();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_pesoShort(max), style: TextStyle(color: colors.textTertiary, fontSize: 11)),
        const SizedBox(height: 4),
        SizedBox(
          height: _height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final b in buckets)
                Expanded(
                  child: Tooltip(
                    message: '${weekly ? 'Week of ' : ''}${dateFormat.format(b.start)}: ${_peso(b.amount)}',
                    child: Container(
                      // 2px gap between bars; empty days keep a hairline so the
                      // timeline still reads as continuous.
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: b.amount == 0 ? 2 : (b.amount / max * _height).clamp(4, _height),
                      decoration: BoxDecoration(
                        color: b.amount == 0 ? colors.borderSubtle : colors.ink,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.border),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(dateFormat.format(buckets.first.start), style: TextStyle(color: colors.textTertiary, fontSize: 11)),
            Text(weekly ? 'This week' : 'Today', style: TextStyle(color: colors.textTertiary, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({required this.dash});
  final AdminDashboard dash;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cats = dash.categories;
    if (cats.isEmpty) {
      return Text('No sales in this period yet', style: TextStyle(color: colors.textTertiary));
    }
    final total = cats.fold<double>(0, (s, c) => s + c.amount);
    final top = cats.first.amount;
    return Column(
      children: [
        for (final c in cats.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    BookType.fromKey(c.type).label,
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (c.amount / top).clamp(0.02, 1.0),
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors.ink,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 120,
                  child: Text(
                    '${_peso(c.amount)} · ${(c.amount / total * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.trailing});
  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
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
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              if (trailing != null)
                Text(trailing!, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(color: context.colors.ink)),
      );
}

/// Phones have no sidebar, so the dashboard keeps a menu of every section.
class _MobileMenu extends ConsumerWidget {
  const _MobileMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final todo = ref.watch(adminTodoProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Manage', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DashboardNavRow(
          icon: Icons.receipt_long_outlined,
          title: 'Orders',
          subtitle: 'Every customer order — ship, deliver or cancel',
          badge: todo.toShip,
          onTap: () => context.push(AppRoute.adminOrders),
        ),
        DashboardNavRow(
          icon: Icons.menu_book_outlined,
          title: 'Products',
          subtitle: 'Add, edit, restock and remove products',
          onTap: () => context.push(AppRoute.adminProducts),
        ),
        DashboardNavRow(
          icon: Icons.fact_check_outlined,
          title: 'Listing review',
          subtitle: "Approve or reject sellers' new listings",
          badge: todo.listingsToReview,
          onTap: () => context.push(AppRoute.adminListings),
        ),
        DashboardNavRow(
          icon: Icons.storefront_outlined,
          title: 'Sellers',
          subtitle: 'Review applications, suspend or reinstate stores',
          badge: todo.sellerApplications,
          onTap: () => context.push(AppRoute.adminSellers),
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
          subtitle: 'Reply to customers as BookVerse Store',
          badge: todo.unansweredMessages,
          onTap: () => context.push(AppRoute.adminMessages),
        ),
        DashboardNavRow(
          icon: Icons.logout_rounded,
          title: 'Sign out',
          subtitle: 'Log out of BookVerse Admin',
          iconColor: colors.error,
          titleColor: colors.error,
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Sign out?'),
                content: const Text('Are you sure you want to sign out of BookVerse Admin?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text('Sign out', style: TextStyle(color: ctx.colors.error)),
                  ),
                ],
              ),
            );
            if (confirm == true && context.mounted) {
              ref.read(pendingReturnLocationProvider.notifier).state = null;
              ref.read(devGuestModeProvider.notifier).state = false;
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) {
                context.go(AppRoute.home);
              }
            }
          },
        ),
      ],
    );
  }
}
