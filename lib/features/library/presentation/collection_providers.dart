import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/book_collection.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/supabase_collection_repository.dart';
import '../domain/collection_repository.dart';

final collectionRepositoryProvider =
    Provider<CollectionRepository>((ref) => SupabaseCollectionRepository());

final collectionsProvider = StreamProvider<List<BookCollection>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(collectionRepositoryProvider).watchCollections(uid);
});

class CollectionActions {
  CollectionActions(this.ref);
  final Ref ref;

  String? get _uid => ref.read(authStateProvider).value?.uid;

  Future<void> create({required String title, required String description}) async {
    final uid = _uid;
    if (uid == null) return;
    await ref.read(collectionRepositoryProvider).create(uid, title: title, description: description);
  }

  Future<void> addBook(String collectionId, String bookId) async {
    final uid = _uid;
    if (uid == null) return;
    await ref.read(collectionRepositoryProvider).addBook(uid, collectionId, bookId);
  }

  Future<void> removeBook(String collectionId, String bookId) async {
    final uid = _uid;
    if (uid == null) return;
    await ref.read(collectionRepositoryProvider).removeBook(uid, collectionId, bookId);
  }

  Future<void> delete(String collectionId) async {
    final uid = _uid;
    if (uid == null) return;
    await ref.read(collectionRepositoryProvider).delete(uid, collectionId);
  }
}

final collectionActionsProvider = Provider((ref) => CollectionActions(ref));
