abstract class WishlistRepository {
  Stream<Set<String>> watchWishlistIds(String uid);

  Future<void> add(String uid, String bookId);

  Future<void> remove(String uid, String bookId);
}
