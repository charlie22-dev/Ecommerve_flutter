import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/order.dart';
import '../../../core/models/shipping_option.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../../core/widgets/primary_button.dart';
import 'address_providers.dart';
import 'checkout_providers.dart';
import 'payment_webview_screen.dart';
import 'voucher_providers.dart';
import 'widgets/address_picker_sheet.dart';
import 'widgets/voucher_picker_sheet.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _paymentActive = false;

  Future<void> _finishOrder(String orderId) async {
    try {
      await ref
          .read(checkoutControllerProvider.notifier)
          .clearCartAfterPayment(orderId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your order is saved. The cart could not refresh; check My Orders before placing it again.',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    final buyNow = ref.read(buyNowItemProvider.notifier);
    ref.read(checkoutControllerProvider.notifier).endCheckout();
    Future.microtask(() {
      try {
        buyNow.state = null;
      } catch (_) {}
    });
    super.dispose();
  }

  Future<void> _pay() async {
    if (_paymentActive) return;
    final address = ref.read(selectedAddressProvider);
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Add a shipping address first.'),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }

    final method = ref.read(selectedPaymentMethodProvider);
    final controller = ref.read(checkoutControllerProvider.notifier);

    final CheckoutResult result;
    setState(() => _paymentActive = true);
    try {
      if (method == PaymentMethod.cashOnDelivery) {
        result = await controller.payWithCashOnDelivery();
      } else {
        // Online Payment — creates a secure Xendit invoice for GCash, Maya, cards, etc.
        result = await controller.payWithEwallet(type: method.name);
      }

      if (!mounted) return;

      switch (result) {
        case CheckoutAwaitingRedirect(:final orderId, :final checkoutUrl):
          final success = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => PaymentWebViewScreen(
                checkoutUrl: checkoutUrl,
                orderId: orderId,
              ),
            ),
          );
          if (!mounted) return;

          if (success == true) {
            // Payment was confirmed — clear cart and show success dialog
            await _finishOrder(orderId);
            if (!mounted) return;
            await showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Payment Successful!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your order has been confirmed and is being processed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('View Order'),
                      ),
                    ),
                  ],
                ),
              ),
            );
            if (!mounted) return;
            context.go('/orders/$orderId');
          } else {
            // The order already exists. Show its actual status rather than
            // leaving a Place Order button that can reserve the stock again.
            context.go('/orders/$orderId');
          }

        case CheckoutSucceeded(:final orderId):
          await _finishOrder(orderId);
          if (!mounted) return;
          context.go('/orders/$orderId');

        case CheckoutFailed(:final message, :final orderId):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: context.colors.error,
            ),
          );
          if (orderId != null) context.go('/orders/$orderId');
      }
    } finally {
      if (mounted) setState(() => _paymentActive = false);
    }
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave checkout?'),
        content: const Text(
          'Your cart items and order details will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continue Checkout'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Leave', style: TextStyle(color: context.colors.error)),
          ),
        ],
      ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final linesAsync = ref.watch(checkoutLinesProvider);
    final isDirectBuy = ref.watch(buyNowItemProvider) != null;
    final selectedMethod = ref.watch(selectedPaymentMethodProvider);
    final selectedShipping = ref.watch(selectedShippingOptionProvider);
    final address = ref.watch(selectedAddressProvider);
    final appliedVoucher = ref.watch(appliedVoucherProvider);
    final isLoading =
        ref.watch(checkoutControllerProvider).isLoading || _paymentActive;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _confirmLeave();
        if (shouldLeave && context.mounted) {
          context.go(isDirectBuy ? '/home' : '/cart');
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(title: const Text('Checkout')),
        body: linesAsync.when(
          data: (lines) {
            final subtotal = lines.fold<double>(
              0,
              (sum, l) => sum + l.lineTotal,
            );
            final shippingCost = selectedShipping.costFor(subtotal);
            final voucherDiscount = appliedVoucher?.discountFor(subtotal) ?? 0;
            final tax = (subtotal * 12).round() / 100;
            final total = (subtotal + shippingCost + tax - voucherDiscount)
                .clamp(0, double.infinity);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
              children: [
                _SectionCard(
                  onTap: () => AddressPickerSheet.show(context),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: colors.ink),
                      const SizedBox(width: 12),
                      Expanded(
                        child: address == null
                            ? Text(
                                'Add a shipping address',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        address.label,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        address.phoneNumber,
                                        style: TextStyle(
                                          color: colors.textTertiary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${address.recipientName} · ${address.fullAddress}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colors.textTertiary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Text(
                      isDirectBuy ? 'Direct Purchase Item' : 'Items',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (isDirectBuy) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Buy Now · Cart Unaffected',
                          style: TextStyle(
                            color: colors.accentOrange,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                _SectionCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < lines.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 20,
                            thickness: 1,
                            color: colors.border.withValues(alpha: 0.5),
                          ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    lines[i].book.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '₱${lines[i].lineTotal.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  width: 38,
                                  height: 52,
                                  child: BookCoverImage(
                                    url: lines[i].book.coverUrl,
                                    borderRadius: 6,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (lines[i].book.author.isNotEmpty)
                                        Text(
                                          'by ${lines[i].book.author}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: colors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Qty: ${lines[i].quantity}  ·  ₱${lines[i].book.price.toStringAsFixed(2)} each',
                                        style: TextStyle(
                                          color: colors.textTertiary,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Shipping option',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                for (final option in ShippingOption.all)
                  _ShippingOptionTile(
                    option: option,
                    selected: selectedShipping,
                    subtotal: subtotal,
                  ),
                if (subtotal < ShippingOption.freeShippingThreshold)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      'Spend ₱${(ShippingOption.freeShippingThreshold - subtotal).toStringAsFixed(0)} more for free Standard Shipping.',
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                Text('Voucher', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                _SectionCard(
                  onTap: () =>
                      VoucherPickerSheet.show(context, subtotal: subtotal),
                  child: Row(
                    children: [
                      Icon(Icons.local_offer_outlined, color: colors.ink),
                      const SizedBox(width: 12),
                      Expanded(
                        child: appliedVoucher == null
                            ? Text(
                                'Select a voucher',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : Text(
                                '${appliedVoucher.code} · ${appliedVoucher.discountLabel}',
                                style: TextStyle(
                                  color: colors.success,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colors.textTertiary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Payment method',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),

                // ── Cash on Delivery ──────────────────────────────────
                _PaymentMethodTile(
                  isSelected: selectedMethod == PaymentMethod.cashOnDelivery,
                  label: 'Cash on Delivery',
                  subtitle: 'Pay when your order arrives',
                  icon: Icons.payments_outlined,
                  onTap: () =>
                      ref.read(selectedPaymentMethodProvider.notifier).state =
                          PaymentMethod.cashOnDelivery,
                ),

                // ── Online Payment ────────────────────────────────────
                _OnlinePaymentTile(
                  isSelected: selectedMethod != PaymentMethod.cashOnDelivery,
                  onTap: () =>
                      ref.read(selectedPaymentMethodProvider.notifier).state =
                          PaymentMethod.gcash,
                ),

                // Secure payment note
                if (selectedMethod != PaymentMethod.cashOnDelivery) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: colors.accentBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment processed securely via Xendit (GCash, Maya, QR Ph, and more).',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                Text(
                  'Order total',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                _SectionCard(
                  child: Column(
                    children: [
                      _TotalRow('Subtotal', '₱${subtotal.toStringAsFixed(2)}'),
                      _TotalRow(
                        'Shipping',
                        shippingCost == 0
                            ? 'Free'
                            : '₱${shippingCost.toStringAsFixed(2)}',
                      ),
                      _TotalRow('Tax (VAT 12%)', '₱${tax.toStringAsFixed(2)}'),
                      if (appliedVoucher != null)
                        _TotalRow(
                          'Voucher (${appliedVoucher.code})',
                          '−₱${voucherDiscount.toStringAsFixed(2)}',
                          valueColor: colors.success,
                        ),
                      const Divider(height: 20),
                      _TotalRow(
                        'Total Payment',
                        '₱${total.toStringAsFixed(2)}',
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () =>
              Center(child: CircularProgressIndicator(color: colors.ink)),
          error: (err, _) => Center(
            child: Text(
              'Could not load your cart.',
              style: TextStyle(color: colors.error),
            ),
          ),
        ),
        bottomNavigationBar: linesAsync.maybeWhen(
          data: (lines) {
            final subtotal = lines.fold<double>(
              0,
              (sum, l) => sum + l.lineTotal,
            );
            final shippingCost = selectedShipping.costFor(subtotal);
            final voucherDiscount = appliedVoucher?.discountFor(subtotal) ?? 0;
            final tax = (subtotal * 12).round() / 100;
            final total = (subtotal + shippingCost + tax - voucherDiscount)
                .clamp(0, double.infinity);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: PrimaryButton(
                  label: lines.isEmpty
                      ? 'Cart is empty'
                      : 'Place Order · ₱${total.toStringAsFixed(2)}',
                  isLoading: isLoading,
                  onPressed:
                      lines.isEmpty ||
                          isLoading ||
                          lines.any(
                            (line) =>
                                !line.book.inStock ||
                                line.quantity < 1 ||
                                line.quantity > line.book.stock,
                          )
                      ? null
                      : _pay,
                ),
              ),
            );
          },
          orElse: () => null,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Payment method tiles
// ──────────────────────────────────────────────────────────────────────────────

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.isSelected,
    required this.label,
    required this.icon,
    required this.onTap,
    this.subtitle,
  });

  final bool isSelected;
  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? colors.ink : colors.border),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? colors.ink : colors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? colors.ink : colors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Online Payment tile — single clean button, Xendit handles sub-method selection.
class _OnlinePaymentTile extends StatelessWidget {
  const _OnlinePaymentTile({required this.isSelected, required this.onTap});

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? colors.ink : colors.border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.payment_rounded,
              color: isSelected ? colors.ink : colors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Online Payment',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'GCash, Maya, QR Ph & more',
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? colors.ink : colors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Shared section widgets
// ──────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: card,
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(
    this.label,
    this.value, {
    this.valueColor,
    this.emphasize = false,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              fontSize: emphasize ? 15 : 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color:
                  valueColor ?? (emphasize ? colors.ink : colors.textPrimary),
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              fontSize: emphasize ? 18 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShippingOptionTile extends ConsumerWidget {
  const _ShippingOptionTile({
    required this.option,
    required this.selected,
    required this.subtotal,
  });
  final ShippingOption option;
  final ShippingOption selected;
  final double subtotal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isSelected = option.id == selected.id;
    final cost = option.costFor(subtotal);
    return GestureDetector(
      onTap: () =>
          ref.read(selectedShippingOptionProvider.notifier).state = option,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? colors.ink : colors.border),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? colors.ink : colors.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    option.eta,
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              cost == 0 ? 'Free' : '₱${cost.toStringAsFixed(2)}',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
