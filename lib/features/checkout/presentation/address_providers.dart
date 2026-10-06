import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/shipping_address.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/address_repository.dart';

final addressRepositoryProvider = Provider((ref) => AddressRepository());

final addressesProvider = StreamProvider<List<ShippingAddress>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(addressRepositoryProvider).watchAddresses(uid);
});

/// The address selected for the current checkout session — defaults to
/// whichever saved address is marked default once addresses load.
final selectedAddressIdProvider = StateProvider<String?>((ref) => null);

final selectedAddressProvider = Provider<ShippingAddress?>((ref) {
  final addresses = ref.watch(addressesProvider).value ?? const [];
  if (addresses.isEmpty) return null;
  final selectedId = ref.watch(selectedAddressIdProvider);
  if (selectedId != null) {
    for (final a in addresses) {
      if (a.id == selectedId) return a;
    }
  }
  for (final a in addresses) {
    if (a.isDefault) return a;
  }
  return addresses.first;
});

class AddressActions {
  AddressActions(this.ref);
  final Ref ref;

  Future<void> save(ShippingAddress address) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    await ref.read(addressRepositoryProvider).save(uid, address);
  }

  Future<void> delete(String addressId) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    await ref.read(addressRepositoryProvider).delete(uid, addressId);
  }
}

final addressActionsProvider = Provider((ref) => AddressActions(ref));
