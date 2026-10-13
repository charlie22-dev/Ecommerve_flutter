import '../../../core/models/book.dart';
import '../../../core/models/order.dart';
import '../../../core/models/store.dart';
import '../../../core/models/store_message.dart';
import '../../../core/models/voucher.dart';
import '../../../core/services/db.dart';

/// A customer as the admin sees them — `profiles` is readable by admins
/// (the "profiles: read own" policy includes `or is_admin()`).
class CustomerInfo {
  const CustomerInfo({required this.uid, required this.name, required this.email, this.photoUrl});
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;

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

/// A listing waiting for review, with the store that submitted it.
class ReviewListing {
  const ReviewListing({required this.book, required this.storeName});
  final Book book;
  final String storeName;
}

/// Marketplace numbers for the dashboard's selected period.
class AdminDashboard {
  const AdminDashboard({
    required this.days,
    required this.grossSales,
    required this.orderCount,
    required this.commission,
    required this.customerCount,
    required this.activeSellers,
    required this.sales,
    required this.categories,
  });

  final int days;

  /// Value of confirmed orders (COD placed or paid) — what customers spent,
  /// not BookVerse's revenue.
  final double grossSales;
  final int orderCount;

  /// What BookVerse keeps from other stores' sales.
  final double commission;
  final int customerCount;
  final int activeSellers;

  /// Sales per bucket (a day, or a week for long periods), oldest first.
  final List<({DateTime start, double amount})> sales;

  /// Sales per book type, biggest first.
  final List<({String type, double amount})> categories;

  double get averageOrder => orderCount == 0 ? 0 : grossSales / orderCount;
}

/// Things waiting on an admin right now, whatever the period.
class AdminTodoCounts {
  const AdminTodoCounts({required this.toShip, required this.lowStock});
  final int toShip;

  /// Published listings with 5 or fewer left.
  final int lowStock;
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

  // ----------------------------------------------------------------- sellers
  // Approvals, suspensions and moderation run as audited server functions
  // (supabase/schema.sql) — the admin can't flip these columns directly.

  /// Pending applications first, then the newest reviewed ones.
  Stream<List<SellerApplication>> watchApplications() {
    return watchQuery(Tables.sellerApplications, () async {
      final rows = await db.from(Tables.sellerApplications).select().order('created_at', ascending: false);
      final apps = rows.map(SellerApplication.fromRow).toList();
      apps.sort((a, b) => (a.status == 'pending' ? 0 : 1).compareTo(b.status == 'pending' ? 0 : 1));
      return apps;
    });
  }

  Future<void> reviewApplication(String id, {required bool approve, String? note}) async {
    await db.rpc('review_seller_application', params: {
      'p_application_id': id,
      'p_approve': approve,
      'p_note': note,
    });
  }

  /// Seller stores (not the official one).
  Stream<List<Store>> watchStores() {
    return watchQuery(Tables.stores, () async {
      final rows =
          await db.from(Tables.stores).select().eq('is_official', false).order('created_at', ascending: false);
      return rows.map(Store.fromRow).toList();
    });
  }

  Future<void> setStoreStatus(String storeId, {required bool active, required String reason}) async {
    await db.rpc('set_store_status', params: {
      'p_store_id': storeId,
      'p_status': active ? 'active' : 'suspended',
      'p_reason': reason,
    });
  }

  /// Oldest first, so sellers are served in order.
  Stream<List<ReviewListing>> watchListingsForReview() {
    return watchQuery(Tables.books, () async {
      final rows = await db
          .from(Tables.books)
          .select('*, stores(name)')
          .eq('listing_status', 'pending_review')
          .order('updated_at', ascending: true);
      return [
        for (final r in rows)
          ReviewListing(book: Book.fromRow(r), storeName: (r['stores'] as Map?)?['name'] as String? ?? 'Unknown store'),
      ];
    });
  }

  /// [status]: published, rejected or suspended (the last two need a note).
  Future<void> moderateListing(String bookId, String status, {String? note}) async {
    await db.rpc('moderate_listing', params: {'p_book_id': bookId, 'p_status': status, 'p_note': note});
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

  // --------------------------------------------------------------- dashboard

  static const _confirmed = ['toShip', 'toReceive', 'completed'];

  Stream<AdminDashboard> watchDashboard(int days) {
    return watchQuery(Tables.orders, () async {
      final today = DateTime.now();
      final first = DateTime(today.year, today.month, today.day).subtract(Duration(days: days - 1));
      final since = first.toUtc().toIso8601String();

      final orders = await db
          .from(Tables.orders)
          .select('id, total, created_at')
          .inFilter('status', _confirmed)
          .gte('created_at', since);
      final orderIds = {for (final o in orders) o['id'] as String};

      final parts = await db
          .from(Tables.sellerOrders)
          .select('order_id, commission_total, status, stores(is_official)')
          .gte('created_at', since);
      final items = await db
          .from('order_items')
          .select('order_id, unit_price, quantity, books(type)')
          .gte('created_at', since);
      final customers = await db.from(Tables.profiles).select('id').count();
      final sellers =
          await db.from(Tables.stores).select('id').eq('status', 'active').eq('is_official', false).count();

      // Weekly buckets past a month, so bars stay readable.
      final bucketDays = days > 31 ? 7 : 1;
      final bucketCount = (days / bucketDays).ceil();
      final buckets = List<double>.filled(bucketCount, 0);
      var gross = 0.0;
      for (final o in orders) {
        final total = toDouble(o['total']);
        gross += total;
        final created = parseTimestamp(o['created_at']);
        if (created == null) continue;
        final day = DateTime(created.year, created.month, created.day).difference(first).inDays;
        final i = (day ~/ bucketDays).clamp(0, bucketCount - 1);
        buckets[i] += total;
      }

      var commission = 0.0;
      for (final p in parts) {
        final official = (p['stores'] as Map?)?['is_official'] == true;
        if (official || p['status'] == 'cancelled' || !orderIds.contains(p['order_id'])) continue;
        commission += toDouble(p['commission_total']);
      }

      final byType = <String, double>{};
      for (final i in items) {
        if (!orderIds.contains(i['order_id'])) continue;
        final type = (i['books'] as Map?)?['type'] as String? ?? 'other';
        byType[type] = (byType[type] ?? 0) + toDouble(i['unit_price']) * toInt(i['quantity']);
      }
      final categories = [for (final e in byType.entries) (type: e.key, amount: e.value)]
        ..sort((a, b) => b.amount.compareTo(a.amount));

      return AdminDashboard(
        days: days,
        grossSales: gross,
        orderCount: orders.length,
        commission: commission,
        customerCount: customers.count,
        activeSellers: sellers.count,
        sales: [
          for (var i = 0; i < bucketCount; i++)
            (start: first.add(Duration(days: i * bucketDays)), amount: buckets[i]),
        ],
        categories: categories,
      );
    });
  }

  Stream<AdminTodoCounts> watchTodoCounts() {
    return watchQuery(Tables.orders, () async {
      final toShip = await db.from(Tables.orders).select('id').eq('status', 'toShip').count();
      final lowStock = await db
          .from(Tables.books)
          .select('id')
          .eq('listing_status', 'published')
          .lte('stock', lowStockThreshold)
          .count();
      return AdminTodoCounts(toShip: toShip.count, lowStock: lowStock.count);
    });
  }

  Future<Map<String, CustomerInfo>> _customers(Iterable<String> uids) async {
    final ids = uids.toSet().toList();
    if (ids.isEmpty) return const {};
    final rows = await db.from(Tables.profiles).select('id, display_name, email, photo_url').inFilter('id', ids);
    return {
      for (final r in rows)
        r['id'] as String: CustomerInfo(
          uid: r['id'] as String,
          name: r['display_name'] as String? ?? '',
          email: r['email'] as String? ?? '',
          photoUrl: r['photo_url'] as String?,
        ),
    };
  }
}
