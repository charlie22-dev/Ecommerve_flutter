import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/book.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/services/db.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../data/supabase_cart_repository.dart';
import '../domain/cart_line.dart';
import '../domain/cart_repository.dart';

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => SupabaseCartRepository(),
);

final cartItemsProvider = StreamProvider<List<CartItem>>((ref) {
  final uid =
      ref.watch(authStateProvider).value?.uid ?? db.auth.currentUser?.id;
  if (uid == null) return Stream.value(const []);
  return ref.watch(cartRepositoryProvider).watchCart(uid);
});

final cartBookProvider = StreamProvider.autoDispose.family<Book?, String>((
  ref,
  id,
) {
  final repo = ref.watch(bookRepositoryProvider);
  return watchQuery(Tables.books, () => repo.getById(id));
});

/// Keeps quantities joined to current prices, availability and stock.
final cartLinesProvider = FutureProvider<List<CartLine>>((ref) {
  final items = ref.watch(cartItemsProvider).valueOrNull;
  if (items == null) {
    // The cart stream's first value rebuilds this provider with its book
    // dependencies. Keep loading until then, and propagate stream errors.
    return ref.watch(cartItemsProvider.future).then((_) => <CartLine>[]);
  }
  // Register every dependency synchronously so autoDispose book subscriptions
  // stay alive across rebuilds. Watch values, not just each stream's first future.
  final books = [
    for (final item in items) ref.watch(cartBookProvider(item.bookId)),
  ];
  final pendingBooks = [
    for (var i = 0; i < items.length; i++)
      books[i].hasValue
          ? Future.value(books[i].valueOrNull)
          : ref.watch(cartBookProvider(items[i].bookId).future),
  ];
  return Future.wait(pendingBooks).then(
    (loaded) => [
      for (var i = 0; i < items.length; i++)
        if (loaded[i] != null)
          CartLine(book: loaded[i]!, quantity: items[i].quantity),
    ],
  );
});

final cartCountProvider = Provider<int>((ref) {
  // Show number of unique products in cart (not total quantity sum)
  final items = ref.watch(cartItemsProvider).value ?? const [];
  return items.length;
});

/// Book IDs explicitly checked/selected for purchase in the cart.
/// If null, all currently in-stock cart items are selected by default.
final selectedCartBookIdsProvider = StateProvider<Set<String>?>((ref) => null);

class CartActions {
  CartActions(this.ref);
  final Ref ref;

  String? get _uid =>
      ref.read(authStateProvider).value?.uid ?? db.auth.currentUser?.id;

  Future<void> setQuantity(String bookId, int quantity) async {
    final uid = _uid;
    if (uid == null) return;
    await ref.read(cartRepositoryProvider).setQuantity(uid, bookId, quantity);
    ref.invalidate(cartItemsProvider);
  }

  Future<void> add(String bookId, {int quantity = 1}) async {
    final uid = _uid;
    if (uid == null) return;
    final current = ref.read(cartItemsProvider).value ?? const [];
    final existing = current.where((c) => c.bookId == bookId).firstOrNull;
    await ref
        .read(cartRepositoryProvider)
        .setQuantity(uid, bookId, (existing?.quantity ?? 0) + quantity);
    ref.invalidate(cartItemsProvider);
  }

  Future<void> remove(String bookId) async {
    final uid = _uid;
    if (uid == null) return;
    await ref.read(cartRepositoryProvider).remove(uid, bookId);
    ref.invalidate(cartItemsProvider);
    ref.invalidate(cartLinesProvider);
  }

  Future<void> removeMany(List<String> bookIds) async {
    final uid = _uid;
    if (uid == null || bookIds.isEmpty) return;
    await ref.read(cartRepositoryProvider).clear(uid, bookIds);
    ref.invalidate(cartItemsProvider);
    ref.invalidate(cartLinesProvider);
  }

  Future<void> clear(List<String> bookIds) async {
    final uid = _uid;
    if (uid == null) return;
    await ref.read(cartRepositoryProvider).clear(uid, bookIds);
    ref.invalidate(cartItemsProvider);
    ref.invalidate(cartLinesProvider);
  }
}

final cartActionsProvider = Provider((ref) => CartActions(ref));

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
