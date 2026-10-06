import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/shipping_address.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/widgets/primary_button.dart';
import '../address_providers.dart';

class AddressFormSheet extends ConsumerStatefulWidget {
  const AddressFormSheet({super.key, this.existing});

  final ShippingAddress? existing;

  static Future<void> show(BuildContext context, {ShippingAddress? existing}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => AddressFormSheet(existing: existing),
    );
  }

  @override
  ConsumerState<AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.existing?.label ?? 'Home');
  late final _name = TextEditingController(text: widget.existing?.recipientName ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phoneNumber ?? '');
  late final _address = TextEditingController(text: widget.existing?.addressLine ?? '');
  late final _city = TextEditingController(text: widget.existing?.city ?? '');
  late final _province = TextEditingController(text: widget.existing?.province ?? '');
  late final _postal = TextEditingController(text: widget.existing?.postalCode ?? '');
  bool _isDefault = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isDefault = widget.existing?.isDefault ?? true;
  }

  @override
  void dispose() {
    for (final c in [_label, _name, _phone, _address, _city, _province, _postal]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final address = ShippingAddress(
      id: widget.existing?.id ?? '',
      label: _label.text.trim().isEmpty ? 'Home' : _label.text.trim(),
      recipientName: _name.text.trim(),
      phoneNumber: _phone.text.trim(),
      addressLine: _address.text.trim(),
      city: _city.text.trim(),
      province: _province.text.trim(),
      postalCode: _postal.text.trim(),
      isDefault: _isDefault,
    );
    await ref.read(addressActionsProvider).save(address);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.existing == null ? 'Add Address' : 'Edit Address', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _label,
                          style: TextStyle(color: colors.textPrimary),
                          decoration: const InputDecoration(labelText: 'Label (Home, Work…)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Recipient name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Phone number'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Street address'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _city,
                          style: TextStyle(color: colors.textPrimary),
                          decoration: const InputDecoration(labelText: 'City'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _province,
                          style: TextStyle(color: colors.textPrimary),
                          decoration: const InputDecoration(labelText: 'Province'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _postal,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Postal code'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _isDefault,
                    onChanged: (v) => setState(() => _isDefault = v),
                    title: const Text('Set as default address'),
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: colors.ink,
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(label: 'Save Address', isLoading: _saving, onPressed: _save),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
