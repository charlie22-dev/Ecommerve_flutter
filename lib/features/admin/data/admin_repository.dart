import '../../../core/models/book.dart';
import '../../../core/models/order.dart';
import '../../../core/models/store_message.dart';
import '../../../core/models/voucher.dart';
import '../../../core/services/db.dart';

/// A customer as the admin sees them — `profiles` is readable by admins
/// (the "profiles: read own" policy includes `or is_admin()`).
class CustomerInfo {
  const CustomerInfo({required this.uid, required this.name, required this.email});
  final String uid;
  final String name;
  final String email;

  String get label => name.isNotEmpty ? name : (email.isNotEmpty ? email : 'Customer');
}

class AdminOrder {
  const AdminOrder({required this.order, required this.customer});
  final Order order;
  final CustomerInfo? customer;
}

/// One customer's message thread, summarized for the admin inbox.
class AdminThread {
  const AdminThread({required this.customer, required this.lastMessage, required this.awaitingReply});
  final CustomerInfo customer;
  final StoreMessage lastMessage;

  /// The customer spoke last — the store hasn't answered yet.
  bool get needsReply => awaitingReply;
  final bool awaitingReply;
}

class AdminStats {
  const AdminStats({
    required this.productCount,
    required this.lowStockCount,
    required this.ordersByStatus,
    required this.revenue,
    required this.customerCount,
  });

  final int productCount;
  final int lowStockCount;
  final Map<OrderStatus, int> ordersByStatus;

  /// Sum of completed orders.
  final double revenue;
  final int customerCount;

  int count(OrderStatus s) => ordersByStatus[s] ?? 0;
}

/// Everything the admin panel reads/writes beyond the shopper-facing
/// repositories. Every call is still checked by Row Level Security — a
/// non-admin calling these just gets their own rows (or an error).
class AdminRepository {
  static const lowStockThreshold = 5;

  // ---------------------------------------------------------------- products

  Stream<List<Book>> watchProducts({String search = ''}) {
    final q = search.trim().replaceAll(RegExp(r'[,()%*\\]'), ' ').trim();
    return watchQuery(Tables.books, () async {
      var query = db.from(Tables.books).select();
      if (q.isNotEmpty) query = query.or('title.ilike.%$q%,author.ilike.%$q%,isbn.ilike.%$q%');
      final rows = await query.order('created_at', ascending: false);
      return rows.map(Book.fromRow).toList();
    });
  }

  Future<void> setStock(String bookId, int stock) async {
    await db.from(Tables.books).update({'stock': stock < 0 ? 0 : stock}).eq('id', bookId);
  }

  /// Deletes the product row, then (best effort) its uploaded cover file.
  Future<void> deleteProduct(Book book) async {
    await db.from(Tables.books).delete().eq('id', book.id);
    final path = _bucketPath(book.coverUrl, 'book-covers');
    if (path != null) {
      try {
        await db.storage.from('book-covers').remove([path]);
      } catch (_) {
        // An orphaned image is harmless; the product is already gone.
      }
    }
  }

  static String? _bucketPath(String url, String bucket) {
    final marker = '/storage/v1/object/public/$bucket/';
    final i = url.indexOf(marker);
    if (i < 0) return null;
    return Uri.decodeComponent(url.substring(i + marker.length).split('?').first);
  }

  // ------------------------------------------------------------------ orders

  Stream<List<AdminOrder>> watchAllOrders() {
    return watchQuery(Tables.orders, () async {
      final rows = await db.from(Tables.orders).select().order('created_at', ascending: false);
      final orders = rows.map(Order.fromRow).toList();
      final customers = await _customers(orders.map((o) => o.uid));
      return [for (final o in orders) AdminOrder(order: o, customer: customers[o.uid])];
    });
  }

  // ---------------------------------------------------------------- vouchers

  /// Includes inactive and expired vouchers (the shopper list hides them).
  Stream<List<Voucher>> watchAllVouchers() {
    return watchQuery(Tables.vouchers, () async {
      final rows = await db.from(Tables.vouchers).select().order('created_at', ascending: false);
      return rows.map(Voucher.fromRow).toList();
    });
  }

  Future<void> saveVoucher(Voucher v) async {
    final row = {
      'code': v.code.trim().toUpperCase(),
      'title': v.title,
      'description': v.description,
      'discount_type': v.discountType.name,
      'discount_value': v.discountValue,
      'min_purchase': v.minPurchase,
      'max_discount': v.maxDiscount,
      'expires_at': v.expiresAt?.toUtc().toIso8601String(),
      'is_active': v.isActive,
    };
    if (v.id.isEmpty) {
      await db.from(Tables.vouchers).insert(row);
    } else {
      await db.from(Tables.vouchers).update(row).eq('id', v.id);
    }
  }

  Future<void> setVoucherActive(String id, bool active) async {
    await db.from(Tables.vouchers).update({'is_active': active}).eq('id', id);
  }

  Future<void> deleteVoucher(String id) async {
    await db.from(Tables.vouchers).delete().eq('id', id);
  }

  // ---------------------------------------------------------------- messages

  Stream<List<AdminThread>> watchThreads() {
    return watchQuery(Tables.messages, () async {
      final rows = await db.from(Tables.messages).select().order('created_at', ascending: false);
      final latestByUser = <String, StoreMessage>{};
      for (final m in rows.map(StoreMessage.fromRow)) {
        latestByUser.putIfAbsent(m.uid, () => m); // rows are newest-first
      }
      final customers = await _customers(latestByUser.keys);
      final threads = [
        for (final e in latestByUser.entries)
          AdminThread(
            customer: customers[e.key] ?? CustomerInfo(uid: e.key, name: '', email: ''),
            lastMessage: e.value,
            awaitingReply: e.value.sender == MessageSender.user,
          ),
      ];
      // Unanswered threads first, then most recent.
      threads.sort((a, b) {
        if (a.needsReply != b.needsReply) return a.needsReply ? -1 : 1;
        return (b.lastMessage.createdAt ?? DateTime(0)).compareTo(a.lastMessage.createdAt ?? DateTime(0));
      });
      return threads;
    });
  }

  Future<CustomerInfo?> customer(String uid) async => (await _customers([uid]))[uid];

  Future<void> sendStoreReply(String customerUid, String text) async {
    await db.from(Tables.messages).insert({'user_id': customerUid, 'sender': 'store', 'text': text});
  }

  // ------------------------------------------------------------------- stats

  Stream<AdminStats> watchStats() {
    return watchQuery(Tables.orders, () async {
      final books = await db.from(Tables.books).select('stock');
      final orders = await db.from(Tables.orders).select('status, total');
      final customers = await db.from(Tables.profiles).select('id').count();

      final byStatus = <OrderStatus, int>{};
      var revenue = 0.0;
      for (final o in orders) {
        final status = OrderStatus.fromKey(o['status'] as String?);
        byStatus[status] = (byStatus[status] ?? 0) + 1;
        if (status == OrderStatus.completed) revenue += toDouble(o['total']);
      }
      return AdminStats(
        productCount: books.length,
        lowStockCount: books.where((b) => toInt(b['stock']) <= lowStockThreshold).length,
        ordersByStatus: byStatus,
        revenue: revenue,
        customerCount: customers.count,
      );
    });
  }

  Future<Map<String, CustomerInfo>> _customers(Iterable<String> uids) async {
    final ids = uids.toSet().toList();
    if (ids.isEmpty) return const {};
    final rows = await db.from(Tables.profiles).select('id, display_name, email').inFilter('id', ids);
    return {
      for (final r in rows)
        r['id'] as String: CustomerInfo(
          uid: r['id'] as String,
          name: r['display_name'] as String? ?? '',
          email: r['email'] as String? ?? '',
        ),
    };
  }
}
