import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/supabase_wishlist_repository.dart';
import '../domain/wishlist_repository.dart';

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) => SupabaseWishlistRepository());

final wishlistIdsProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const {});
  return ref.watch(wishlistRepositoryProvider).watchWishlistIds(uid);
});

class WishlistActions {
  WishlistActions(this.ref);
  final Ref ref;

  Future<void> toggle(String bookId, bool isWishlisted) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    final repo = ref.read(wishlistRepositoryProvider);
    if (isWishlisted) {
      await repo.remove(uid, bookId);
    } else {
      await repo.add(uid, bookId);
    }
  }
}

final wishlistActionsProvider = Provider((ref) => WishlistActions(ref));
