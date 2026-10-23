import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/seller_order.dart';
import '../../../core/models/store.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/db.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/dashboard_tiles.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/presentation/auth_providers.dart';
import 'seller_providers.dart';
import 'seller_rules.dart';
import '../../messages/presentation/message_providers.dart';

/// Seller Center: the application form (or its status) until an admin
/// approves the user, then the store dashboard.
class SellerCenterScreen extends ConsumerWidget {
  const SellerCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final storeAsync = ref.watch(myStoreProvider);

    return storeAsync.when(
      data: (store) => store == null
          ? Scaffold(appBar: AppBar(title: const Text('Become a Seller')), body: const _ApplyView())
          : _Dashboard(store: store),
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Seller Center')),
        body: Center(child: CircularProgressIndicator(color: colors.ink)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Seller Center')),
        body: Center(child: Text('Could not load your store.\n$e', textAlign: TextAlign.center)),
      ),
    );
  }
}

// ---------------------------------------------------------------- dashboard --

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.store});
  final Store store;

  static const _lowStock = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final listings = ref.watch(myListingsProvider).value ?? const [];
    final orders = ref.watch(myStoreOrdersProvider).value ?? const <SellerOrder>[];
    final rate = ref.watch(myCommissionRateProvider).value;
    final unreadMessages = ref.watch(sellerConversationsProvider(store.id)).value?.fold<int>(0, (sum, c) => sum + c.unreadCount) ?? 0;

    final delivered = orders.where((o) => o.status == SellerOrderStatus.delivered);
    final gross = delivered.fold<double>(0, (sum, o) => sum + o.subtotal);
    final commission = delivered.fold<double>(0, (sum, o) => sum + o.commissionTotal);
    final toFulfill = orders.where((o) => o.status.needsAction).length;
    final inTransit = orders.where((o) => o.status == SellerOrderStatus.shipped).length;
    final live = listings.where((b) => b.listingStatus == 'published').toList();
    final inReview = listings.where((b) => b.listingStatus == 'pending_review').length;
    final lowStock = live.where((b) => b.stock <= _lowStock).length;

    String peso(double v) => '₱${NumberFormat('#,##0.00').format(v)}';

    return Scaffold(
      appBar: AppBar(title: Text(store.name)),
      floatingActionButton: store.isActive
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoute.sellerAddProduct),
              backgroundColor: colors.ink,
              foregroundColor: colors.onInk,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Listing'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          if (!store.isActive)
            _Banner(
              icon: Icons.block_rounded,
              color: colors.error,
              text: 'Your store is suspended. Your listings are hidden and you can\'t make changes. '
                  'Check your notifications for the reason, or message BookVerse Store.',
            ),
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
                label: 'Your earnings',
                value: peso(gross - commission),
                icon: Icons.account_balance_wallet_outlined,
                color: colors.success,
              ),
              StatTile(
                label: 'Gross sales',
                value: peso(gross),
                icon: Icons.payments_outlined,
                color: colors.info,
              ),
              StatTile(
                label: 'To fulfill',
                value: '$toFulfill',
                icon: Icons.inventory_2_outlined,
                color: colors.accentBlue,
                highlight: toFulfill > 0,
                onTap: () => context.push(AppRoute.sellerOrders),
              ),
              StatTile(
                label: 'In transit',
                value: '$inTransit',
                icon: Icons.local_shipping_outlined,
                color: colors.star,
                onTap: () => context.push(AppRoute.sellerOrders),
              ),
              StatTile(
                label: 'Live listings',
                value: '${live.length}',
                icon: Icons.menu_book_outlined,
                color: colors.ink,
                onTap: () => context.push(AppRoute.sellerProducts),
              ),
              StatTile(
                label: 'Low stock (≤$_lowStock)',
                value: '$lowStock',
                icon: Icons.warning_amber_rounded,
                color: colors.accentOrange,
                highlight: lowStock > 0,
                onTap: () => context.push(AppRoute.sellerProducts),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Earnings count delivered orders only, after the '
            '${rate == null ? '' : '${(rate * 100).toStringAsFixed(rate * 100 % 1 == 0 ? 0 : 1)}% '}'
            'platform commission (₱${commission.toStringAsFixed(2)} so far). Payouts are handled by BookVerse.',
            style: TextStyle(color: colors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 24),
          Text('Manage', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DashboardNavRow(
            icon: Icons.receipt_long_outlined,
            title: 'Orders',
            subtitle: toFulfill == 0 ? 'Confirm, ship and track your orders' : '$toFulfill waiting for you',
            badge: toFulfill,
            onTap: () => context.push(AppRoute.sellerOrders),
          ),
          DashboardNavRow(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Messages',
            subtitle: unreadMessages == 0
                ? 'Reply to customer inquiries'
                : '$unreadMessages waiting for reply',
            badge: unreadMessages,
            onTap: () => context.push(AppRoute.sellerMessages),
          ),
          DashboardNavRow(
            icon: Icons.shield_rounded,
            title: 'Contact BookVerse Admin',
            subtitle: 'Direct support & inquiries for sellers',
            onTap: () async {
              final official = await ref.read(officialStoreProvider.future);
              if (official == null) return;
              try {
                final convId = await ref.read(messageActionsProvider).getOrCreateConversation(official.id);
                if (context.mounted) {
                  context.push('/messages/conversation/$convId?storeName=BookVerse%20Admin');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not open chat: $e')),
                  );
                }
              }
            },
          ),
          DashboardNavRow(
            icon: Icons.menu_book_outlined,
            title: 'Listings',
            subtitle: inReview == 0
                ? '${listings.length} listing${listings.length == 1 ? '' : 's'}'
                : '${listings.length} listings · $inReview in review',
            onTap: () => context.push(AppRoute.sellerProducts),
          ),
          DashboardNavRow(
            icon: Icons.gavel_rounded,
            title: 'Seller rules',
            subtitle: 'What you can sell and how',
            onTap: () => showSellerRulesSheet(context),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: context.colors.textPrimary, fontSize: 13))),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- application --

class _ApplyView extends ConsumerWidget {
  const _ApplyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final appAsync = ref.watch(mySellerApplicationProvider);

    return appAsync.when(
      data: (app) {
        if (app?.status == 'pending') {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Banner(
                icon: Icons.hourglass_top_rounded,
                color: colors.accentOrange,
                text: 'Your application for "${app!.storeName}" is being reviewed'
                    '${app.createdAt == null ? '' : ' (sent ${DateFormat.yMMMd().format(app.createdAt!)})'}. '
                    'You\'ll get a notification once an admin decides.',
              ),
            ],
          );
        }
        return _ApplyForm(rejected: app?.status == 'rejected' ? app : null);
      },
      loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
      error: (e, _) => Center(child: Text('Could not load your application.\n$e', textAlign: TextAlign.center)),
    );
  }
}

class _ApplyForm extends ConsumerStatefulWidget {
  const _ApplyForm({this.rejected});

  /// The previous, rejected application — its details prefill the form.
  final SellerApplication? rejected;

  @override
  ConsumerState<_ApplyForm> createState() => _ApplyFormState();
}

class _ApplyFormState extends ConsumerState<_ApplyForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.rejected?.storeName);
  late final _description = TextEditingController(text: widget.rejected?.description);
  late final _email = TextEditingController(
    text: widget.rejected?.contactEmail ?? ref.read(appUserProvider).value?.email,
  );
  late final _phone = TextEditingController(text: widget.rejected?.contactPhone);
  bool _sending = false;
  bool _agreed = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please agree to the seller rules first.')));
      return;
    }
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    setState(() => _sending = true);
    try {
      await ref.read(sellerRepositoryProvider).apply(
            uid: uid,
            storeName: _name.text.trim(),
            description: _description.text.trim(),
            contactEmail: _email.text.trim(),
            contactPhone: _phone.text.trim(),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send: ${errorMessage(e)}')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    String? required(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.rejected != null)
              _Banner(
                icon: Icons.info_outline_rounded,
                color: colors.error,
                text: 'Your last application wasn\'t approved: ${widget.rejected!.adminNote ?? 'no reason given'}. '
                    'Update your details and apply again.',
              ),
            Text(
              'Sell your books and comics on BookVerse. Tell us about your store — an admin reviews every '
              'application before you can list products.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              style: TextStyle(color: colors.textPrimary),
              decoration: const InputDecoration(labelText: 'Store name *'),
              validator: (v) {
                final len = (v ?? '').trim().length;
                return len < 2 || len > 80 ? 'Use 2 to 80 characters' : null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              style: TextStyle(color: colors.textPrimary),
              decoration: const InputDecoration(labelText: 'What do you sell? *'),
              validator: required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: colors.textPrimary),
              decoration: const InputDecoration(labelText: 'Contact email *'),
              validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: colors.textPrimary),
              decoration: const InputDecoration(labelText: 'Contact number *'),
              validator: required,
            ),
            const SizedBox(height: 24),
            Text('Seller rules', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const SellerRulesList(),
            CheckboxListTile(
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: colors.ink,
              title: Text(
                'I have read and agree to the seller rules',
                style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(label: 'Submit Application', isLoading: _sending, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
