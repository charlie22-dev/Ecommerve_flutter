import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/cart_item.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../data/supabase_cart_repository.dart';
import '../domain/cart_line.dart';
import '../domain/cart_repository.dart';

final cartRepositoryProvider = Provider<CartRepository>((ref) => SupabaseCartRepository());

final cartItemsProvider = StreamProvider<List<CartItem>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(cartRepositoryProvider).watchCart(uid);
});

/// Joins raw cart rows with their `Book` documents. Re-fetches per emission,
/// which is fine at cart-sized item counts and keeps prices/stock current
/// at checkout time.
final cartLinesProvider = FutureProvider<List<CartLine>>((ref) async {
  final items = await ref.watch(cartItemsProvider.future);
  final repo = ref.watch(bookRepositoryProvider);

  final lines = <CartLine>[];
  for (final item in items) {
    final book = await repo.getById(item.bookId);
    if (book != null) lines.add(CartLine(book: book, quantity: item.quantity));
  }
  return lines;
});

final cartCountProvider = Provider<int>((ref) {
  final items = ref.watch(cartItemsProvider).value ?? const [];
  return items.fold<int>(0, (sum, item) => sum + item.quantity);
});

class CartActions {
  CartActions(this.ref);
  final Ref ref;

  Future<void> setQuantity(String bookId, int quantity) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    await ref.read(cartRepositoryProvider).setQuantity(uid, bookId, quantity);
  }

  Future<void> add(String bookId, {int quantity = 1}) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    final current = ref.read(cartItemsProvider).value ?? const [];
    final existing = current.where((c) => c.bookId == bookId).firstOrNull;
    await ref.read(cartRepositoryProvider).setQuantity(
          uid,
          bookId,
          (existing?.quantity ?? 0) + quantity,
        );
  }

  Future<void> remove(String bookId) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    await ref.read(cartRepositoryProvider).remove(uid, bookId);
  }

  Future<void> clear(List<String> bookIds) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    await ref.read(cartRepositoryProvider).clear(uid, bookIds);
  }
}

final cartActionsProvider = Provider((ref) => CartActions(ref));

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
