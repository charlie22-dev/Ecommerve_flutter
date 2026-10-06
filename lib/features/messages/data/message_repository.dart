import '../../../core/models/store_message.dart';
import '../../../core/services/db.dart';

class MessageRepository {
  Stream<List<StoreMessage>> watchThread(String uid) {
    return watchQuery(Tables.messages, () async {
      final rows = await db.from(Tables.messages).select().eq('user_id', uid).order('created_at');
      return rows.map(StoreMessage.fromRow).toList();
    });
  }

  Future<void> send(String uid, String text) async {
    await db
        .from(Tables.messages)
        .insert(StoreMessage(id: '', uid: uid, sender: MessageSender.user, text: text).toRow());
  }

  /// A one-time canned welcome — not a live reply — written client-side the
  /// first time a user opens an empty thread. See store_message.dart.
  Future<void> sendStoreWelcome(String uid) async {
    await db.from(Tables.messages).insert(
          StoreMessage(
            id: '',
            uid: uid,
            sender: MessageSender.store,
            text: "Hi! You're messaging BookVerse Store. We usually reply within 24 hours — let us know if you need "
                "a hand with an order, a book request, or anything else.",
          ).toRow(),
        );
  }
}
