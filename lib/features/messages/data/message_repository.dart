import '../../../core/models/store.dart';
import '../../../core/models/store_message.dart';
import '../../../core/services/db.dart';
import '../../admin/data/admin_repository.dart' show CustomerInfo;

/// Handles database operations for customer support messages and store conversations.
class MessageRepository {
  /// Watches messages for a specific buyer thread.
  /// If [storeId] is null, watches the thread with BookVerse Official support.
  /// If [storeId] is set, watches the thread between this buyer and that seller.
  Stream<List<StoreMessage>> watchThread(String uid, {String? storeId}) {
    return watchQuery(Tables.messages, () async {
      final rows = await db
          .from(Tables.messages)
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: true);
      return rows
          .map(StoreMessage.fromRow)
          .where((m) => m.storeId == storeId)
          .toList();
    });
  }

  /// Sends a customer message to the store support or seller conversation thread.
  Future<void> send(String uid, String text, {String? storeId}) async {
    await db.from(Tables.messages).insert(
          StoreMessage(
            id: '',
            uid: uid,
            sender: MessageSender.user,
            text: text,
            storeId: storeId,
          ).toRow(),
        );
  }

  /// Sends a reply from an approved seller's store to a customer.
  Future<void> sendSellerReply(String customerUid, String storeId, String text) async {
    await db.from(Tables.messages).insert(
          StoreMessage(
            id: '',
            uid: customerUid,
            sender: MessageSender.store,
            text: text,
            storeId: storeId,
          ).toRow(),
        );
  }

  /// A one-time canned welcome — not a live reply — posted by the
  /// `send_store_welcome` function (customers can't post as the store) the
  /// first time a user opens an empty thread.
  Future<void> sendStoreWelcome(String uid) async {
    try {
      await db.rpc('send_store_welcome');
    } catch (_) {}
  }

  /// All approved seller stores that customers can message.
  Stream<List<Store>> watchApprovedStores() {
    return watchQuery(Tables.stores, () async {
      final rows = await db
          .from(Tables.stores)
          .select()
          .eq('is_official', false)
          .eq('status', 'active')
          .order('name', ascending: true);
      return rows.map(Store.fromRow).toList();
    });
  }

  /// Notifies the seller of a new buyer message via an RPC function.
  /// Fails silently if the `notify_seller_on_message` function doesn't exist yet.
  Future<void> notifySellerOnMessage(String storeId, String title, String body) async {
    await db.rpc('notify_seller_on_message', params: {
      'p_store_id': storeId,
      'p_title': title,
      'p_body': body,
    });
  }

  /// Customer threads received by an approved seller's store.
  Stream<List<SellerCustomerThread>> watchSellerThreads(String storeId) {
    return watchQuery(Tables.messages, () async {
      final rows = await db
          .from(Tables.messages)
          .select()
          .order('created_at', ascending: false);
      final messages = rows
          .map(StoreMessage.fromRow)
          .where((m) => m.storeId == storeId)
          .toList();

      final latestByUser = <String, StoreMessage>{};
      for (final m in messages) {
        latestByUser.putIfAbsent(m.uid, () => m);
      }

      final customers = await _fetchCustomers(latestByUser.keys);
      final threads = [
        for (final e in latestByUser.entries)
          SellerCustomerThread(
            customer: customers[e.key] ?? CustomerInfo(uid: e.key, name: '', email: ''),
            lastMessage: e.value,
            awaitingReply: e.value.sender == MessageSender.user,
          ),
      ];

      threads.sort((a, b) {
        if (a.needsReply != b.needsReply) return a.needsReply ? -1 : 1;
        return (b.lastMessage.createdAt ?? DateTime(0)).compareTo(a.lastMessage.createdAt ?? DateTime(0));
      });
      return threads;
    });
  }

  Future<Map<String, CustomerInfo>> _fetchCustomers(Iterable<String> uids) async {
    final ids = uids.toSet().toList();
    if (ids.isEmpty) return const {};
    try {
      final rows = await db
          .from(Tables.profiles)
          .select('id, display_name, email, photo_url')
          .inFilter('id', ids);
      return {
        for (final r in rows)
          r['id'] as String: CustomerInfo(
            uid: r['id'] as String,
            name: r['display_name'] as String? ?? '',
            email: r['email'] as String? ?? '',
            photoUrl: r['photo_url'] as String?,
          ),
      };
    } catch (_) {
      return {
        for (final id in ids)
          id: CustomerInfo(uid: id, name: 'Customer (${id.length >= 6 ? id.substring(0, 6) : id})', email: ''),
      };
    }
  }
}

class SellerCustomerThread {
  const SellerCustomerThread({
    required this.customer,
    required this.lastMessage,
    required this.awaitingReply,
  });

  final CustomerInfo customer;
  final StoreMessage lastMessage;
  final bool awaitingReply;

  bool get needsReply => awaitingReply;
}
