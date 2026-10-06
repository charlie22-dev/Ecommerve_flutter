import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_color_tokens.dart';
import '../address_providers.dart';
import 'address_form_sheet.dart';

class AddressPickerSheet extends ConsumerWidget {
  const AddressPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const AddressPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final addresses = ref.watch(addressesProvider).value ?? const [];
    final selectedId = ref.watch(selectedAddressProvider)?.id;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shipping addresses', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (addresses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No saved addresses yet.', style: TextStyle(color: colors.textSecondary)),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: addresses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final a = addresses[i];
                    final selected = a.id == selectedId;
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        ref.read(selectedAddressIdProvider.notifier).state = a.id;
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: selected ? colors.ink : colors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? colors.ink : colors.textTertiary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(a.label, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
                                      const SizedBox(width: 6),
                                      Text('(${a.phoneNumber})', style: TextStyle(color: colors.textTertiary, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(a.recipientName, style: TextStyle(color: colors.textPrimary, fontSize: 13)),
                                  Text(a.fullAddress, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit',
                              icon: Icon(Icons.edit_outlined, size: 18, color: colors.textTertiary),
                              onPressed: () {
                                Navigator.of(context).pop();
                                AddressFormSheet.show(context, existing: a);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                AddressFormSheet.show(context);
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add new address'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ),
      ),
    );
  }
}
