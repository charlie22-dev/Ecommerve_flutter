import '../../../core/models/shipping_address.dart';
import '../../../core/services/db.dart';

class AddressRepository {
  Stream<List<ShippingAddress>> watchAddresses(String uid) {
    return watchQuery(Tables.addresses, () async {
      final rows = await db.from(Tables.addresses).select().eq('user_id', uid);
      return rows.map(ShippingAddress.fromRow).toList();
    });
  }

  /// Insert (empty id) or update. Marking one address default clears the
  /// others in the `addresses_single_default` trigger.
  Future<void> save(String uid, ShippingAddress address) async {
    await db.from(Tables.addresses).upsert(address.toRow(uid));
  }

  Future<void> delete(String uid, String addressId) async {
    await db.from(Tables.addresses).delete().eq('id', addressId).eq('user_id', uid);
  }
}
