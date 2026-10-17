import '../../../core/models/cart_item.dart';

/// Data access contract for managing a shopper's shopping cart items.
abstract class CartRepository {
  Stream<List<CartItem>> watchCart(String uid);

  Future<void> setQuantity(String uid, String bookId, int quantity);

  Future<void> remove(String uid, String bookId);

  Future<void> clear(String uid, List<String> bookIds);
}
