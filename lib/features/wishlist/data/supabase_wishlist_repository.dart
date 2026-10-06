import '../../../core/services/db.dart';
import '../domain/wishlist_repository.dart';

class SupabaseWishlistRepository implements WishlistRepository {
  @override
  Stream<Set<String>> watchWishlistIds(String uid) {
    return watchQuery(Tables.wishlistItems, () async {
      final rows = await db.from(Tables.wishlistItems).select('book_id').eq('user_id', uid);
      return rows.map((r) => r['book_id'] as String).toSet();
    });
  }

  @override
  Future<void> add(String uid, String bookId) async {
    await db.from(Tables.wishlistItems).upsert({'user_id': uid, 'book_id': bookId});
  }

  @override
  Future<void> remove(String uid, String bookId) async {
    await db.from(Tables.wishlistItems).delete().eq('user_id', uid).eq('book_id', bookId);
  }
}
