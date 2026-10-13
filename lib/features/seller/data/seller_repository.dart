import '../../../core/models/book.dart';
import '../../../core/models/seller_order.dart';
import '../../../core/models/store.dart';
import '../../../core/services/db.dart';

/// The Seller Center's data. Row Level Security limits every query to the
/// caller's own store, and status changes go through server functions
/// (supabase/schema.sql), so nothing here is trusted for security.
class SellerRepository {
  Stream<Store?> watchMyStore(String uid) {
    return watchQuery(Tables.stores, () async {
      final row = await db.from(Tables.stores).select().eq('owner_id', uid).maybeSingle();
      return row == null ? null : Store.fromRow(row);
    });
  }

  /// The latest application, if any.
  Stream<SellerApplication?> watchMyApplication(String uid) {
    return watchQuery(Tables.sellerApplications, () async {
      final row = await db
          .from(Tables.sellerApplications)
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row == null ? null : SellerApplication.fromRow(row);
    });
  }

  Future<void> apply({
    required String uid,
    required String storeName,
    required String description,
    required String contactEmail,
    required String contactPhone,
  }) async {
    await db.from(Tables.sellerApplications).insert({
      'user_id': uid,
      'store_name': storeName,
      'description': description,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
    });
  }

  /// Every listing of the store, whatever its status.
  Stream<List<Book>> watchListings(String storeId) {
    return watchQuery(Tables.books, () async {
      final rows =
          await db.from(Tables.books).select().eq('store_id', storeId).order('created_at', ascending: false);
      return rows.map(Book.fromRow).toList();
    });
  }

  Stream<List<SellerOrder>> watchOrders(String storeId) {
    return watchQuery(Tables.sellerOrders, () async {
      final rows = await db
          .from(Tables.sellerOrders)
          .select('*, order_items(*)')
          .eq('store_id', storeId)
          .order('created_at', ascending: false);
      return rows.map(SellerOrder.fromRow).toList();
    });
  }

  /// A buyer's view of who is shipping what in one of their orders.
  Stream<List<SellerOrder>> watchShipments(String orderId) {
    return watchQuery(Tables.sellerOrders, () async {
      final rows = await db
          .from(Tables.sellerOrders)
          .select('*, stores(name)')
          .eq('order_id', orderId)
          .order('created_at', ascending: true);
      return rows.map(SellerOrder.fromRow).toList();
    });
  }

  /// Confirm, ship (with courier + tracking) or mark delivered — the
  /// server checks the order is yours and the step is allowed.
  Future<void> updateOrder(String sellerOrderId, SellerOrderStatus status, {String? carrier, String? tracking}) async {
    await db.rpc('update_seller_order', params: {
      'p_seller_order_id': sellerOrderId,
      'p_status': status.name,
      'p_carrier': carrier,
      'p_tracking': tracking,
    });
  }

  Future<double> platformCommissionRate() async {
    final row = await db.from(Tables.platformSettings).select('commission_rate').maybeSingle();
    return toDouble(row?['commission_rate'], 0.10);
  }
}
