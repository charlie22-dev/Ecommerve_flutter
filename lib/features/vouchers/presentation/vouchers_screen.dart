import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/voucher.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../checkout/presentation/voucher_providers.dart';

/// The Vouchers nav tab — replaces Explore in the bottom nav (search moved
/// to the Home search bar, see home_screen.dart). Ticket-style coupon cards
/// matching the reference "My Coupons" layout, adapted to BookVerse's
/// cream/black design tokens instead of the reference's green theme.
class VouchersScreen extends ConsumerWidget {
  const VouchersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final vouchersAsync = ref.watch(activeVouchersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Vouchers')),
      body: vouchersAsync.when(
        data: (vouchers) {
          if (vouchers.isEmpty) {
            return const EmptyState(
              icon: Icons.confirmation_number_outlined,
              title: 'No vouchers right now',
              message: 'Check back later for new discounts and deals.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vouchers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, i) => _CouponTicket(
              voucher: vouchers[i],
              onTap: () => context.push('/vouchers/${vouchers[i].id}'),
            ),
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
        error: (err, _) => Center(child: Text('Could not load vouchers.', style: TextStyle(color: colors.error))),
      ),
    );
  }
}

class _CouponTicket extends StatelessWidget {
  const _CouponTicket({required this.voucher, required this.onTap});
  final Voucher voucher;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 92,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
                decoration: BoxDecoration(
                  color: colors.ink,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.confirmation_number_rounded, color: colors.onInk, size: 20),
                      const SizedBox(height: 6),
                      Text(
                        voucher.discountLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onInk, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              _DashedDivider(color: colors.border),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        voucher.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        voucher.minPurchase > 0 ? 'Min. spend ₱${voucher.minPurchase.toStringAsFixed(0)}' : 'No minimum spend',
                        style: TextStyle(color: colors.textSecondary, fontSize: 12),
                      ),
                      if (voucher.expiresAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Expires ${voucher.expiresAt!.month}/${voucher.expiresAt!.day}/${voucher.expiresAt!.year}',
                          style: TextStyle(color: colors.textTertiary, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = (constraints.maxHeight / 8).floor().clamp(1, 100);
          return Column(
            children: List.generate(
              count,
              (_) => Expanded(child: Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 2), color: color)),
            ),
          );
        },
      ),
    );
  }
}
