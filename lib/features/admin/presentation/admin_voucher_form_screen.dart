import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/voucher.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/primary_button.dart';
import 'admin_providers.dart';

/// Create (`voucherId == null`) or edit a voucher.
class AdminVoucherFormScreen extends ConsumerStatefulWidget {
  const AdminVoucherFormScreen({super.key, this.voucherId});
  final String? voucherId;

  @override
  ConsumerState<AdminVoucherFormScreen> createState() => _AdminVoucherFormScreenState();
}

class _AdminVoucherFormScreenState extends ConsumerState<AdminVoucherFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _value = TextEditingController();
  final _minPurchase = TextEditingController(text: '0');
  final _maxDiscount = TextEditingController();
  DiscountType _type = DiscountType.percent;
  DateTime? _expiresAt;
  bool _isActive = true;
  bool _prefilled = false;
  bool _saving = false;

  bool get _isEditing => widget.voucherId != null;

  @override
  void dispose() {
    for (final c in [_code, _title, _description, _value, _minPurchase, _maxDiscount]) {
      c.dispose();
    }
    super.dispose();
  }

  void _prefill(Voucher v) {
    if (_prefilled) return;
    _prefilled = true;
    _code.text = v.code;
    _title.text = v.title;
    _description.text = v.description;
    _value.text = _trim(v.discountValue);
    _minPurchase.text = _trim(v.minPurchase);
    _maxDiscount.text = v.maxDiscount == null ? '' : _trim(v.maxDiscount!);
    _type = v.discountType;
    _expiresAt = v.expiresAt;
    _isActive = v.isActive;
  }

  static String _trim(double d) => d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(2);

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    // End of the chosen day, so "until Oct 31" includes Oct 31.
    if (picked != null) setState(() => _expiresAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final voucher = Voucher(
      id: widget.voucherId ?? '',
      code: _code.text.trim().toUpperCase(),
      title: _title.text.trim(),
      description: _description.text.trim(),
      discountType: _type,
      discountValue: double.parse(_value.text.trim()),
      minPurchase: double.tryParse(_minPurchase.text.trim()) ?? 0,
      maxDiscount: _type == DiscountType.percent ? double.tryParse(_maxDiscount.text.trim()) : null,
      expiresAt: _expiresAt,
      isActive: _isActive,
    );
    try {
      await ref.read(adminRepositoryProvider).saveVoucher(voucher);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEditing ? 'Voucher updated' : 'Voucher created')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      final duplicate = e.toString().contains('duplicate key') || e.toString().contains('23505');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(duplicate ? 'A voucher with code ${voucher.code} already exists.' : 'Could not save: $e'),
        backgroundColor: context.colors.error,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this voucher?'),
        content: const Text('Customers will no longer be able to use this code. To pause it instead, switch it off.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: context.colors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(adminRepositoryProvider).deleteVoucher(widget.voucherId!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing && !_prefilled) {
      final vouchers = ref.watch(adminVouchersProvider);
      final match = vouchers.value?.where((v) => v.id == widget.voucherId).firstOrNull;
      if (match == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Edit Voucher')),
          body: Center(
            child: vouchers.isLoading ? CircularProgressIndicator(color: context.colors.ink) : const Text('Voucher not found'),
          ),
        );
      }
      _prefill(match);
    }

    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Voucher' : 'New Voucher'),
        actions: [
          if (_isEditing) IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Label('Code *'),
              TextFormField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                decoration: const InputDecoration(hintText: 'e.g. SUMMER25'),
                validator: (v) {
                  final code = (v ?? '').trim();
                  if (code.isEmpty) return 'Enter a code';
                  if (!RegExp(r'^[A-Za-z0-9_-]{3,20}$').hasMatch(code)) return '3–20 letters/numbers, no spaces';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const _Label('Title *'),
              TextFormField(
                controller: _title,
                style: TextStyle(color: colors.textPrimary),
                decoration: const InputDecoration(hintText: 'Shown on the Vouchers tab'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 16),
              const _Label('Description'),
              TextFormField(controller: _description, maxLines: 2, style: TextStyle(color: colors.textPrimary)),
              const SizedBox(height: 16),
              const _Label('Discount type'),
              SegmentedButton<DiscountType>(
                segments: const [
                  ButtonSegment(value: DiscountType.percent, label: Text('% off')),
                  ButtonSegment(value: DiscountType.fixed, label: Text('₱ off')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label(_type == DiscountType.percent ? 'Percent off *' : 'Amount off *'),
                        TextFormField(
                          controller: _value,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: colors.textPrimary),
                          decoration: InputDecoration(
                            prefixText: _type == DiscountType.fixed ? '₱ ' : null,
                            suffixText: _type == DiscountType.percent ? '%' : null,
                          ),
                          validator: (v) {
                            final n = double.tryParse((v ?? '').trim());
                            if (n == null || n <= 0) return 'Enter an amount';
                            if (_type == DiscountType.percent && n > 100) return 'Max 100%';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Min. spend'),
                        TextFormField(
                          controller: _minPurchase,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: colors.textPrimary),
                          decoration: const InputDecoration(prefixText: '₱ '),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_type == DiscountType.percent) ...[
                const SizedBox(height: 16),
                const _Label('Max discount (optional)'),
                TextFormField(
                  controller: _maxDiscount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: colors.textPrimary),
                  decoration: const InputDecoration(prefixText: '₱ ', hintText: 'No cap'),
                ),
              ],
              const SizedBox(height: 16),
              const _Label('Expires'),
              InkWell(
                onTap: _pickExpiry,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_outlined, size: 18, color: colors.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _expiresAt == null ? 'Never expires' : DateFormat.yMMMd().format(_expiresAt!),
                          style: TextStyle(color: _expiresAt == null ? colors.textTertiary : colors.textPrimary),
                        ),
                      ),
                      if (_expiresAt != null)
                        GestureDetector(
                          onTap: () => setState(() => _expiresAt = null),
                          child: Icon(Icons.close_rounded, size: 18, color: colors.textTertiary),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Active', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text('Customers can see and use this code', style: TextStyle(color: colors.textTertiary, fontSize: 12)),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: _isEditing ? 'Save Changes' : 'Create Voucher', isLoading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(color: context.colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
      );
}
