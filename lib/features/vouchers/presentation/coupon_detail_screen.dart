import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../checkout/presentation/voucher_providers.dart';

class CouponDetailScreen extends ConsumerWidget {
  const CouponDetailScreen({super.key, required this.voucherId});
  final String voucherId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final voucherAsync = ref.watch(voucherByIdProvider(voucherId));

    return Scaffold(
      appBar: AppBar(title: const Text('Coupon Details')),
      body: voucherAsync.when(
        data: (voucher) {
          if (voucher == null) {
            return Center(
              child: Text('This voucher is no longer available.', style: TextStyle(color: colors.textSecondary)),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(color: colors.ink, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      Text(
                        voucher.discountLabel,
                        style: TextStyle(color: colors.onInk, fontWeight: FontWeight.w900, fontSize: 32),
                      ),
                      const SizedBox(height: 6),
                      Text(voucher.title, style: TextStyle(color: colors.onInk, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          voucher.code,
                          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 2),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: voucher.code));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (voucher.description.isNotEmpty) ...[
                  Text('About this voucher', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(voucher.description, style: TextStyle(color: colors.textSecondary, fontSize: 13.5, height: 1.5)),
                  const SizedBox(height: 20),
                ],
                Text('Terms', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _TermRow(label: 'Minimum spend', value: voucher.minPurchase > 0 ? '₱${voucher.minPurchase.toStringAsFixed(0)}' : 'None'),
                if (voucher.maxDiscount != null)
                  _TermRow(label: 'Maximum discount', value: '₱${voucher.maxDiscount!.toStringAsFixed(0)}'),
                _TermRow(
                  label: 'Valid until',
                  value: voucher.expiresAt == null
                      ? 'No expiry'
                      : '${voucher.expiresAt!.month}/${voucher.expiresAt!.day}/${voucher.expiresAt!.year}',
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go(AppRoute.store),
                    child: const Text('Shop Now'),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
        error: (err, _) => Center(child: Text('Could not load this voucher.', style: TextStyle(color: colors.error))),
      ),
    );
  }
}

class _TermRow extends StatelessWidget {
  const _TermRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
