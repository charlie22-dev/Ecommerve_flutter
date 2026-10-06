import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/voucher.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import 'admin_providers.dart';

/// All vouchers, including inactive/expired ones — toggle, edit, add.
class AdminVouchersScreen extends ConsumerWidget {
  const AdminVouchersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final vouchersAsync = ref.watch(adminVouchersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Vouchers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('${AppRoute.adminVouchers}/new'),
        backgroundColor: colors.ink,
        foregroundColor: colors.onInk,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Voucher'),
      ),
      body: vouchersAsync.when(
        data: (vouchers) {
          if (vouchers.isEmpty) {
            return const EmptyState(
              icon: Icons.confirmation_number_outlined,
              title: 'No vouchers yet',
              message: 'Create a discount code customers can apply at checkout.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            itemCount: vouchers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _VoucherTile(voucher: vouchers[i]),
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
        error: (e, _) => Center(child: Text('Could not load vouchers.\n$e', textAlign: TextAlign.center)),
      ),
    );
  }
}

class _VoucherTile extends ConsumerWidget {
  const _VoucherTile({required this.voucher});
  final Voucher voucher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final v = voucher;
    final live = v.isActive && !v.isExpired;
    final status = v.isExpired ? 'Expired' : (v.isActive ? 'Active' : 'Off');

    return InkWell(
      onTap: () => context.push('${AppRoute.adminVouchers}/${v.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        v.code,
                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status,
                        style: TextStyle(
                          color: live ? colors.success : colors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${v.discountLabel}'
                    '${v.minPurchase > 0 ? ' · min ₱${v.minPurchase.toStringAsFixed(0)}' : ''}'
                    '${v.expiresAt != null ? ' · until ${DateFormat.yMMMd().format(v.expiresAt!)}' : ''}',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch(
              value: v.isActive,
              onChanged: (on) => ref.read(adminRepositoryProvider).setVoucherActive(v.id, on),
            ),
          ],
        ),
      ),
    );
  }
}
