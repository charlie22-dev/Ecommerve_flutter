import '../../../core/models/store_message.dart';
import '../../../core/services/db.dart';

/// Handles database operations for customer support messages and store conversations.
class MessageRepository {
  Stream<List<StoreMessage>> watchThread(String uid) {
    return watchQuery(Tables.messages, () async {
      final rows = await db.from(Tables.messages).select().eq('user_id', uid).order('created_at', ascending: true);
      return rows.map(StoreMessage.fromRow).toList();
    });
  }

  /// Sends a customer message to the store support conversation thread.
  Future<void> send(String uid, String text) async {
    await db
        .from(Tables.messages)
        .insert(StoreMessage(id: '', uid: uid, sender: MessageSender.user, text: text).toRow());
  }

  /// A one-time canned welcome — not a live reply — posted by the
  /// `send_store_welcome` function (customers can't post as the store) the
  /// first time a user opens an empty thread. See store_message.dart.
  Future<void> sendStoreWelcome(String uid) async {
    await db.rpc('send_store_welcome');
  }
}
