import '../../../core/models/book_collection.dart';
import '../../../core/services/db.dart';
import '../domain/collection_repository.dart';

class SupabaseCollectionRepository implements CollectionRepository {
  @override
  Stream<List<BookCollection>> watchCollections(String uid) {
    return watchQuery(Tables.collections, () async {
      final rows =
          await db.from(Tables.collections).select().eq('user_id', uid).order('updated_at', ascending: false);
      return rows.map(BookCollection.fromRow).toList();
    });
  }

  @override
  Future<String> create(String uid, {required String title, required String description}) async {
    final row = await db
        .from(Tables.collections)
        .insert({'user_id': uid, 'title': title, 'description': description})
        .select('id')
        .single();
    return row['id'] as String;
  }

  @override
  Future<void> addBook(String uid, String collectionId, String bookId) async {
    final ids = await _bookIds(uid, collectionId);
    if (ids.contains(bookId)) return;
    await _setBookIds(uid, collectionId, [...ids, bookId]);
  }

  @override
  Future<void> removeBook(String uid, String collectionId, String bookId) async {
    final ids = await _bookIds(uid, collectionId);
    await _setBookIds(uid, collectionId, ids.where((id) => id != bookId).toList());
  }

  @override
  Future<void> delete(String uid, String collectionId) async {
    await db.from(Tables.collections).delete().eq('id', collectionId).eq('user_id', uid);
  }

  Future<List<String>> _bookIds(String uid, String collectionId) async {
    final row =
        await db.from(Tables.collections).select('book_ids').eq('id', collectionId).eq('user_id', uid).single();
    return stringList(row['book_ids']);
  }

  Future<void> _setBookIds(String uid, String collectionId, List<String> ids) async {
    await db.from(Tables.collections).update({'book_ids': ids}).eq('id', collectionId).eq('user_id', uid);
  }
}
