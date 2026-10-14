import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/voucher.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../checkout/presentation/voucher_providers.dart';

/// Shown once per app session, right after Home first builds (see
/// home_screen.dart) — an in-memory flag, not SharedPreferences, so it
/// naturally reappears the next time the app is cold-started rather than
/// only ever once per install like the launch splash.
final homeVoucherPopupShownProvider = StateProvider<bool>((ref) => false);

class VoucherPopup extends ConsumerWidget {
  const VoucherPopup({super.key});

  static Future<void> showIfNeeded(BuildContext context, WidgetRef ref) async {
    if (ref.read(homeVoucherPopupShownProvider)) return;
    final vouchers = await ref.read(activeVouchersProvider.future).catchError((_) => const <Voucher>[]);
    if (vouchers.isEmpty) return;
    ref.read(homeVoucherPopupShownProvider.notifier).state = true;
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => VoucherPopup(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final vouchers = ref.watch(activeVouchersProvider).value ?? const [];
    final featured = vouchers.take(2).toList();

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      // Phone-width on desktop too, instead of stretching across the screen.
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Semantics(
                button: true,
                label: 'Close',
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, color: colors.textTertiary),
                  ),
                ),
              ),
            ),
            Icon(Icons.local_offer_rounded, color: colors.ink, size: 36),
            const SizedBox(height: 12),
            Text(
              'Vouchers just for you',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Save on your next order with these active vouchers.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            for (final voucher in featured) ...[
              _VoucherRow(voucher: voucher),
              if (voucher != featured.last) const SizedBox(height: 10),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go(AppRoute.vouchers);
              },
              child: const Text('View All Vouchers'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoucherRow extends StatelessWidget {
  const _VoucherRow({required this.voucher});
  final Voucher voucher;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: colors.ink, borderRadius: BorderRadius.circular(8)),
            child: Text(voucher.discountLabel, style: TextStyle(color: colors.onInk, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(voucher.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
