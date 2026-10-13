import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/store.dart';
import '../../../core/services/db.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/text_prompt_dialog.dart';
import 'admin_providers.dart';
import 'admin_shell.dart';
import 'widgets/admin_table.dart';

/// Seller applications to approve/reject, and stores to suspend/reinstate.
/// Every decision is recorded in the audit log by the server.
class AdminSellersScreen extends ConsumerWidget {
  const AdminSellersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sellers'),
          bottom: TabBar(
            labelColor: colors.textPrimary,
            unselectedLabelColor: colors.textTertiary,
            indicatorColor: colors.ink,
            tabs: const [Tab(text: 'Applications'), Tab(text: 'Stores')],
          ),
        ),
        body: const TabBarView(children: [_Applications(), _Stores()]),
      ),
    );
  }
}

Future<void> _run(BuildContext context, Future<void> Function() action, String done) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    messenger.showSnackBar(SnackBar(content: Text(done)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
  }
}

class _Applications extends ConsumerWidget {
  const _Applications();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return ref.watch(adminApplicationsProvider).when(
          data: (apps) {
            if (apps.isEmpty) {
              return const EmptyState(icon: Icons.storefront_outlined, title: 'No applications yet');
            }
            // Cards, not a table: reviewing means reading the description.
            return Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView.separated(
                  padding: EdgeInsets.all(AdminShell.isWide(context) ? 28 : 20),
                  itemCount: apps.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _ApplicationCard(app: apps[i]),
                ),
              ),
            );
          },
          loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
          error: (e, _) => Center(child: Text('Could not load applications.\n$e', textAlign: TextAlign.center)),
        );
  }
}

class _ApplicationCard extends ConsumerWidget {
  const _ApplicationCard({required this.app});
  final SellerApplication app;

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve "${app.storeName}"?'),
        content: const Text('Their store opens and they can start submitting listings for review.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Approve')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(
      context,
      () => ref.read(adminRepositoryProvider).reviewApplication(app.id, approve: true),
      '${app.storeName} approved',
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final values = await showTextPromptDialog(
      context,
      title: 'Reject "${app.storeName}"?',
      message: 'The applicant sees this reason and can apply again.',
      fields: const ['Reason'],
      confirmLabel: 'Reject',
      destructive: true,
    );
    if (values == null || !context.mounted) return;
    await _run(
      context,
      () => ref.read(adminRepositoryProvider).reviewApplication(app.id, approve: false, note: values.first),
      'Application rejected',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final (label, color) = switch (app.status) {
      'approved' => ('Approved', colors.success),
      'rejected' => ('Rejected', colors.error),
      _ => ('Pending', colors.accentOrange),
    };
    return _Card(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(app.storeName, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
            ),
            StatusChip(label: label, color: color),
          ],
        ),
        if (app.createdAt != null)
          Text('Applied ${DateFormat.yMMMd().format(app.createdAt!)}',
              style: TextStyle(color: colors.textTertiary, fontSize: 12)),
        if (app.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(app.description, style: TextStyle(color: colors.textPrimary, fontSize: 13)),
        ],
        const SizedBox(height: 8),
        Text('${app.contactEmail} · ${app.contactPhone}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        if (app.adminNote != null) ...[
          const SizedBox(height: 4),
          Text('Note: ${app.adminNote}', style: TextStyle(color: colors.textTertiary, fontSize: 12)),
        ],
        if (app.status == 'pending') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _reject(context, ref),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: colors.error)),
                  child: Text('Reject', style: TextStyle(color: colors.error)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => _approve(context, ref),
                  style: FilledButton.styleFrom(backgroundColor: colors.ink, foregroundColor: colors.onInk),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Stores extends ConsumerWidget {
  const _Stores();

  Future<void> _toggle(BuildContext context, WidgetRef ref, Store store) async {
    final suspending = store.isActive;
    final values = await showTextPromptDialog(
      context,
      title: suspending ? 'Suspend ${store.name}?' : 'Reinstate ${store.name}?',
      message: suspending
          ? 'Their listings disappear from the store and they can\'t edit them. The seller sees your reason.'
          : 'Their published listings come back to the store.',
      fields: const ['Reason'],
      confirmLabel: suspending ? 'Suspend' : 'Reinstate',
      destructive: suspending,
    );
    if (values == null || !context.mounted) return;
    await _run(
      context,
      () => ref.read(adminRepositoryProvider).setStoreStatus(store.id, active: !suspending, reason: values.first),
      suspending ? '${store.name} suspended' : '${store.name} reinstated',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return ref.watch(adminStoresProvider).when(
          data: (stores) {
            if (stores.isEmpty) {
              return const EmptyState(
                icon: Icons.storefront_outlined,
                title: 'No seller stores yet',
                message: 'Approved applications show up here.',
              );
            }
            if (AdminShell.isWide(context)) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: AdminTable(
                  columns: const [
                    DataColumn(label: Text('STORE')),
                    DataColumn(label: Text('CONTACT')),
                    DataColumn(label: Text('JOINED')),
                    DataColumn(label: Text('COMMISSION'), numeric: true),
                    DataColumn(label: Text('STATUS')),
                    DataColumn(label: Text('ACTION')),
                  ],
                  rows: [
                    for (final store in stores)
                      adminRow(
                        context,
                        cells: [
                          DataCell(TwoLineCell(store.name, store.description, leading: InitialAvatar(store.name))),
                          DataCell(TwoLineCell(store.contactEmail, store.contactPhone)),
                          DataCell(Text(store.createdAt == null ? '—' : DateFormat.yMMMd().format(store.createdAt!))),
                          DataCell(Text(store.commissionRate == null
                              ? 'Default'
                              : '${(store.commissionRate! * 100).toStringAsFixed(1)}%')),
                          DataCell(StatusChip(
                            label: store.isActive ? 'Active' : 'Suspended',
                            color: store.isActive ? colors.success : colors.error,
                          )),
                          DataCell(TextButton(
                            onPressed: () => _toggle(context, ref, store),
                            child: Text(
                              store.isActive ? 'Suspend' : 'Reinstate',
                              style: TextStyle(
                                color: store.isActive ? colors.error : colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )),
                        ],
                      ),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: stores.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final store = stores[i];
                return _Card(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(store.name,
                              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
                        ),
                        StatusChip(
                          label: store.isActive ? 'Active' : 'Suspended',
                          color: store.isActive ? colors.success : colors.error,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TwoLineCell(store.contactEmail, store.contactPhone, leading: InitialAvatar(store.name)),
                    if (store.commissionRate != null)
                      Text('Commission ${(store.commissionRate! * 100).toStringAsFixed(1)}%',
                          style: TextStyle(color: colors.textTertiary, fontSize: 12)),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        onPressed: () => _toggle(context, ref, store),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: store.isActive ? colors.error : colors.border),
                        ),
                        child: Text(
                          store.isActive ? 'Suspend' : 'Reinstate',
                          style: TextStyle(color: store.isActive ? colors.error : colors.textPrimary),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
          loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
          error: (e, _) => Center(child: Text('Could not load stores.\n$e', textAlign: TextAlign.center)),
        );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
