import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/order.dart';
import '../../../core/models/shipping_option.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/primary_button.dart';
import '../../cart/presentation/cart_providers.dart';
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
  final _cardNumber = TextEditingController();
  final _expiry = TextEditingController();
  final _cvc = TextEditingController();
  final _cardName = TextEditingController();
  final _cardEmail = TextEditingController();

  @override
  void dispose() {
    _cardNumber.dispose();
    _expiry.dispose();
    _cvc.dispose();
    _cardName.dispose();
    _cardEmail.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final address = ref.read(selectedAddressProvider);
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Add a shipping address first.'), backgroundColor: context.colors.error),
      );
      return;
    }

    final method = ref.read(selectedPaymentMethodProvider);
    final controller = ref.read(checkoutControllerProvider.notifier);

    final result = switch (method) {
      PaymentMethod.cashOnDelivery => await controller.payWithCashOnDelivery(),
      PaymentMethod.gcash => await controller.payWithEwallet(type: 'gcash'),
      PaymentMethod.maya => await controller.payWithEwallet(type: 'paymaya'),
      PaymentMethod.card => await _submitCard(controller),
    };

    if (!mounted) return;

    switch (result) {
      case CheckoutAwaitingRedirect(:final orderId, :final checkoutUrl):
        final success = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => PaymentWebViewScreen(checkoutUrl: checkoutUrl, orderId: orderId)),
        );
        if (!mounted) return;
        if (success == true) {
          await controller.clearCartAfterPayment();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment Verified! Order has been placed.'),
              backgroundColor: Colors.green,
            ),
          );
        }
        if (!mounted) return;
        context.go('/order-confirmation/$orderId');
      case CheckoutSucceeded(:final orderId):
        await controller.clearCartAfterPayment();
        if (!mounted) return;
        context.go('/order-confirmation/$orderId');
      case CheckoutFailed(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: context.colors.error),
        );
    }
  }

  Future<CheckoutResult> _submitCard(CheckoutController controller) async {
    final email = _cardEmail.text.trim();
    final name = _cardName.text.trim();
    int month = 12;
    int year = 2030;
    if (_expiry.text.isNotEmpty && _expiry.text.contains('/')) {
      final parts = _expiry.text.split('/');
      month = int.tryParse(parts[0].trim()) ?? 12;
      final y = int.tryParse(parts[1].trim()) ?? 30;
      year = y < 100 ? 2000 + y : y;
    }

    return controller.payWithCard(
      cardNumber: _cardNumber.text.trim(),
      expMonth: month,
      expYear: year,
      cvc: _cvc.text.trim(),
      billingName: name,
      billingEmail: email,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final linesAsync = ref.watch(cartLinesProvider);
    final selectedMethod = ref.watch(selectedPaymentMethodProvider);
    final selectedShipping = ref.watch(selectedShippingOptionProvider);
    final address = ref.watch(selectedAddressProvider);
    final appliedVoucher = ref.watch(appliedVoucherProvider);
    final isLoading = ref.watch(checkoutControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Checkout')),
      body: linesAsync.when(
        data: (lines) {
          final subtotal = lines.fold<double>(0, (sum, l) => sum + l.lineTotal);
          final shippingCost = selectedShipping.costFor(subtotal);
          final voucherDiscount = appliedVoucher?.discountFor(subtotal) ?? 0;
          final total = (subtotal + shippingCost - voucherDiscount).clamp(0, double.infinity);

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
                          ? Text('Add a shipping address', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(address.label, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
                                    const SizedBox(width: 8),
                                    Text(address.phoneNumber, style: TextStyle(color: colors.textTertiary, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${address.recipientName} · ${address.fullAddress}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                                ),
                              ],
                            ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text('Items', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              _SectionCard(
                child: Column(
                  children: [
                    for (final l in lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${l.book.title} ×${l.quantity}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: colors.textSecondary, fontSize: 13),
                              ),
                            ),
                            Text('₱${l.lineTotal.toStringAsFixed(2)}', style: TextStyle(color: colors.textPrimary, fontSize: 13)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text('Shipping option', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              for (final option in ShippingOption.all)
                _ShippingOptionTile(option: option, selected: selectedShipping, subtotal: subtotal),
              if (subtotal < ShippingOption.freeShippingThreshold)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    'Spend ₱${(ShippingOption.freeShippingThreshold - subtotal).toStringAsFixed(0)} more for free Standard Shipping.',
                    style: TextStyle(color: colors.textTertiary, fontSize: 11.5),
                  ),
                ),
              const SizedBox(height: 16),

              Text('Voucher', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              _SectionCard(
                onTap: () => VoucherPickerSheet.show(context, subtotal: subtotal),
                child: Row(
                  children: [
                    Icon(Icons.local_offer_outlined, color: colors.ink),
                    const SizedBox(width: 12),
                    Expanded(
                      child: appliedVoucher == null
                          ? Text('Select a voucher', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600))
                          : Text(
                              '${appliedVoucher.code} · ${appliedVoucher.discountLabel}',
                              style: TextStyle(color: colors.success, fontWeight: FontWeight.w700),
                            ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text('Payment method', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              _PaymentMethodTile(
                method: PaymentMethod.cashOnDelivery,
                selected: selectedMethod,
                label: 'Cash on Delivery',
                subtitle: 'Pay when your order arrives',
                icon: Icons.payments_outlined,
              ),
              _PaymentMethodTile(
                method: PaymentMethod.gcash,
                selected: selectedMethod,
                label: 'GCash',
                icon: Icons.account_balance_wallet_rounded,
              ),
              _PaymentMethodTile(
                method: PaymentMethod.maya,
                selected: selectedMethod,
                label: 'Maya',
                icon: Icons.account_balance_wallet_outlined,
              ),
              _PaymentMethodTile(
                method: PaymentMethod.card,
                selected: selectedMethod,
                label: 'Credit / Debit Card',
                icon: Icons.credit_card_rounded,
              ),
              if (selectedMethod == PaymentMethod.card) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _cardName,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Name on card'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _cardEmail,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Billing email'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _cardNumber,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Card number'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _expiry,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: const InputDecoration(labelText: 'MM/YY'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _cvc,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: const InputDecoration(labelText: 'CVC'),
                      ),
                    ),
                  ],
                ),
              ],
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
                      Icon(Icons.shield_outlined, size: 16, color: colors.accentBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Payment processed securely via Xendit (GCash, Maya, and Cards supported).',
                          style: TextStyle(color: colors.textSecondary, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              Text('Order total', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              _SectionCard(
                child: Column(
                  children: [
                    _TotalRow('Subtotal', '₱${subtotal.toStringAsFixed(2)}'),
                    _TotalRow('Shipping', shippingCost == 0 ? 'Free' : '₱${shippingCost.toStringAsFixed(2)}'),
                    if (appliedVoucher != null)
                      _TotalRow('Voucher (${appliedVoucher.code})', '−₱${voucherDiscount.toStringAsFixed(2)}', valueColor: colors.success),
                    const Divider(height: 20),
                    _TotalRow('Total Payment', '₱${total.toStringAsFixed(2)}', emphasize: true),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
        error: (err, _) => Center(child: Text('Could not load your cart.', style: TextStyle(color: colors.error))),
      ),
      bottomNavigationBar: linesAsync.maybeWhen(
        data: (lines) {
          final subtotal = lines.fold<double>(0, (sum, l) => sum + l.lineTotal);
          final shippingCost = selectedShipping.costFor(subtotal);
          final voucherDiscount = appliedVoucher?.discountFor(subtotal) ?? 0;
          final total = (subtotal + shippingCost - voucherDiscount).clamp(0, double.infinity);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: PrimaryButton(
                label: lines.isEmpty ? 'Cart is empty' : 'Place Order · ₱${total.toStringAsFixed(2)}',
                isLoading: isLoading,
                onPressed: lines.isEmpty ? null : _pay,
              ),
            ),
          );
        },
        orElse: () => null,
      ),
    );
  }
}

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
    return InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: card);
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, {this.valueColor, this.emphasize = false});
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
              color: valueColor ?? (emphasize ? colors.ink : colors.textPrimary),
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
  const _ShippingOptionTile({required this.option, required this.selected, required this.subtotal});
  final ShippingOption option;
  final ShippingOption selected;
  final double subtotal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isSelected = option.id == selected.id;
    final cost = option.costFor(subtotal);
    return GestureDetector(
      onTap: () => ref.read(selectedShippingOptionProvider.notifier).state = option,
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
                  Text(option.label, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                  Text(option.eta, style: TextStyle(color: colors.textTertiary, fontSize: 11.5)),
                ],
              ),
            ),
            Text(
              cost == 0 ? 'Free' : '₱${cost.toStringAsFixed(2)}',
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends ConsumerWidget {
  const _PaymentMethodTile({
    required this.method,
    required this.selected,
    required this.label,
    required this.icon,
    this.subtitle,
  });

  final PaymentMethod method;
  final PaymentMethod selected;
  final String label;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isSelected = method == selected;
    return GestureDetector(
      onTap: () => ref.read(selectedPaymentMethodProvider.notifier).state = method,
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
            Icon(icon, color: isSelected ? colors.ink : colors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(color: colors.textTertiary, fontSize: 11.5)),
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
