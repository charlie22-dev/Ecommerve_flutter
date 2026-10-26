import '../../../core/models/cart_item.dart';
import '../../../core/services/db.dart';
import '../domain/cart_repository.dart';

class SupabaseCartRepository implements CartRepository {
  @override
  Stream<List<CartItem>> watchCart(String uid) {
    return watchQuery(Tables.cartItems, () async {
      final rows =
          await db.from(Tables.cartItems).select().eq('user_id', uid).order('added_at', ascending: false);
      return rows.map(CartItem.fromRow).toList();
    });
  }

  @override
  Future<void> setQuantity(String uid, String bookId, int quantity) async {
    if (quantity <= 0) {
      await remove(uid, bookId);
      return;
    }
    // Update existing row quantity so added_at is preserved, preventing item re-ordering
    final updated = await db
        .from(Tables.cartItems)
        .update({'quantity': quantity})
        .eq('user_id', uid)
        .eq('book_id', bookId)
        .select();
    if (updated.isEmpty) {
      await db.from(Tables.cartItems).insert({
        'user_id': uid,
        'book_id': bookId,
        'quantity': quantity,
        'added_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  @override
  Future<void> remove(String uid, String bookId) async {
    await db.from(Tables.cartItems).delete().eq('user_id', uid).eq('book_id', bookId);
  }

  @override
  Future<void> clear(String uid, List<String> bookIds) async {
    if (bookIds.isEmpty) return;
    for (final id in bookIds) {
      await db.from(Tables.cartItems).delete().eq('user_id', uid).eq('book_id', id);
    }
  }
}
