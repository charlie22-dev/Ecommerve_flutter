import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/voucher.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/widgets/primary_button.dart';
import '../voucher_providers.dart';

class VoucherPickerSheet extends ConsumerStatefulWidget {
  const VoucherPickerSheet({super.key, required this.subtotal});
  final double subtotal;

  static Future<void> show(BuildContext context, {required double subtotal}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => VoucherPickerSheet(subtotal: subtotal),
    );
  }

  @override
  ConsumerState<VoucherPickerSheet> createState() => _VoucherPickerSheetState();
}

class _VoucherPickerSheetState extends ConsumerState<VoucherPickerSheet> {
  final _codeController = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _applyCode(String code) async {
    if (code.trim().isEmpty) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final voucher = await ref.read(voucherRepositoryProvider).getByCode(code);
    if (!mounted) return;
    setState(() => _checking = false);
    if (voucher == null) {
      setState(() => _error = 'That code isn\'t valid.');
      return;
    }
    _apply(voucher);
  }

  void _apply(Voucher voucher) {
    if (!voucher.isEligible(widget.subtotal)) {
      setState(() => _error = 'Minimum purchase of ₱${voucher.minPurchase.toStringAsFixed(0)} required for this voucher.');
      return;
    }
    ref.read(appliedVoucherProvider.notifier).state = voucher;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vouchersAsync = ref.watch(activeVouchersProvider);
    final applied = ref.watch(appliedVoucherProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Apply a voucher', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: const InputDecoration(hintText: 'Enter voucher code'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: PrimaryButton(label: 'Apply', isLoading: _checking, onPressed: () => _applyCode(_codeController.text)),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: colors.error, fontSize: 12)),
              ],
              if (applied != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(appliedVoucherProvider.notifier).state = null;
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: Text('Remove "${applied.code}"'),
                ),
              ],
              const SizedBox(height: 20),
              Text('Available vouchers', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                child: vouchersAsync.when(
                  data: (vouchers) {
                    if (vouchers.isEmpty) {
                      return Text('No vouchers available right now.', style: TextStyle(color: colors.textSecondary));
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: vouchers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final v = vouchers[i];
                        final eligible = v.isEligible(widget.subtotal);
                        return Opacity(
                          opacity: eligible ? 1 : 0.5,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: eligible ? () => _apply(v) : null,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: colors.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: colors.ink, borderRadius: BorderRadius.circular(8)),
                                    child: Text(v.discountLabel, style: TextStyle(color: colors.onInk, fontWeight: FontWeight.w800, fontSize: 12)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(v.title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                                        Text(
                                          v.minPurchase > 0 ? 'Min. spend ₱${v.minPurchase.toStringAsFixed(0)}' : v.code,
                                          style: TextStyle(color: colors.textTertiary, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
                  error: (err, _) => Text('Could not load vouchers.', style: TextStyle(color: colors.error)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
