import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../domain/cart_line.dart';
import 'cart_providers.dart';
import '../../checkout/presentation/checkout_providers.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linesAsync = ref.watch(cartLinesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: linesAsync.when(
        data: (lines) {
          if (lines.isEmpty) {
            return const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message: 'Browse the catalog and add a few titles.',
            );
          }
          final subtotal = lines.fold<double>(0, (sum, l) => sum + l.lineTotal);

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: lines.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    if (i == lines.length) return const _SeeAllVouchersRow();
                    return _CartLineTile(line: lines[i]);
                  },
                ),
              ),
              _CheckoutBar(subtotal: subtotal),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: context.colors.ink)),
        error: (err, _) => Center(
          child: Text('Could not load your cart.', style: TextStyle(color: context.colors.error)),
        ),
      ),
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          SizedBox(width: 56, height: 84, child: BookCoverImage(url: line.book.coverUrl)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '₱${line.book.price.toStringAsFixed(0)}',
                  style: TextStyle(color: context.colors.ink, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove_rounded,
                      onTap: () => ref.read(cartActionsProvider).setQuantity(line.book.id, line.quantity - 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('${line.quantity}', style: TextStyle(color: context.colors.textPrimary)),
                    ),
                    _QtyButton(
                      icon: Icons.add_rounded,
                      onTap: () => ref.read(cartActionsProvider).setQuantity(line.book.id, line.quantity + 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove ${line.book.title} from cart',
            icon: Icon(Icons.delete_outline_rounded, color: context.colors.textTertiary),
            onPressed: () => ref.read(cartActionsProvider).remove(line.book.id),
          ),
        ],
      ),
    );
  }
}

class _SeeAllVouchersRow extends StatelessWidget {
  const _SeeAllVouchersRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      // `go`, not `push` — Vouchers is a bottom-nav shell branch with its
      // own persistent Navigator/GlobalKey inside the IndexedStack. Cart is
      // a route pushed OUTSIDE that shell, so pushing a shell-branch path
      // from here tried to build a second instance of that branch's
      // Navigator while the shell's own instance was still alive — that's
      // the "!keyReservation.contains(key) is not true" crash. `go`
      // re-enters the shell properly instead of nesting another copy of it.
      onTap: () => context.go(AppRoute.vouchers),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.local_offer_outlined, color: colors.ink, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text('See all vouchers', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: icon == Icons.add_rounded ? 'Increase quantity' : 'Decrease quantity',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: context.colors.textPrimary),
        ),
      ),
    );
  }
}

class _CheckoutBar extends ConsumerWidget {
  const _CheckoutBar({required this.subtotal});
  final double subtotal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subtotal', style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
                  Text(
                    '₱${subtotal.toStringAsFixed(2)}',
                    style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 160,
              child: PrimaryButton(
                label: 'Checkout',
                onPressed: () {
                  ref.read(buyNowItemProvider.notifier).state = null;
                  context.push('/checkout');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
